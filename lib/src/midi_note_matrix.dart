// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:aud_midi_standard/aud_midi_standard.dart';

// #############################################################################
/// The notes that sound right now, per channel and note, with the velocity
/// of every Note On that holds them.
///
/// The matrix has [channels] × [notes] cells. Every cell holds velocity
/// slots: a Note On writes its velocity into the first free slot, a Note
/// Off frees the slot filled last, so the occupied slots are contiguous
/// from the front and their number says how many Note Ons hold the note.
/// A cell starts with [initialSlots] slots and doubles them when all are
/// taken, up to [maxSlots]. A full cell counts no further Note On: the
/// newest velocity replaces the slot filled last, so a stream of Note Ons
/// without Note Offs cannot grow the matrix.
///
/// Messages enter through [midiIn] and leave through [midiOut]:
///
/// - the first Note On of a cell is sent;
/// - a repeated Note On sends a Note Off followed by the new Note On while
///   [retriggerRepeatedNoteOns] is true for the channel, and nothing while
///   it is false;
/// - a Note Off that leaves the note held sends nothing;
/// - the last Note Off is sent as received;
/// - a Note Off of a note that is not held is forwarded unchanged, so no
///   note gets stuck behind the matrix;
/// - a Note On with velocity 0 counts as Note Off;
/// - All Sound Off (CC 120), All Notes Off (CC 123) and the mode messages
///   that imply All Notes Off (CC 124 to 127) send a Note Off for every
///   held note of their channel, free its cells and pass through after
///   the Note Offs;
/// - every other message passes through unchanged and in order, so the
///   matrix can sit in a chain in front of an output.
///
/// [release], [releaseChannel] and [releaseAll] let the app end notes
/// whose Note Off will never arrive, e.g. when a port disappears or the
/// app loses focus.
///
/// Channels and notes are 0-based. Arguments outside their ranges fail an
/// assertion in debug builds.
final class MidiNoteMatrix {
  /// Creates an empty matrix.
  ///
  /// - [midiOut] receives the messages the matrix sends on; may be set
  ///   later.
  /// - [initialSlots] the number of velocity slots every cell starts
  ///   with, at least 1.
  /// - [maxSlots] the number of Note Ons a cell counts at most, at least
  ///   [initialSlots].
  MidiNoteMatrix({this.midiOut, this.initialSlots = 5, this.maxSlots = 10})
    : assert(initialSlots >= 1),
      assert(maxSlots >= initialSlots),
      _slots = List.generate(
        channels * notes,
        (_) => Uint8List(initialSlots),
        growable: false,
      ),
      _counts = Uint32List(channels * notes),
      _retrigger = List.filled(channels, true);

  // ...........................................................................
  /// Processes [messages] in order and hands the messages that result to
  /// [midiOut] in one call.
  ///
  /// Note On, Note Off and the channel mode messages that end notes
  /// update the matrix and are sent by the rules of this class; every
  /// other message passes through unchanged. [midiOut] is not called when
  /// no message results.
  void midiIn(List<MidiMessage> messages) {
    final out = <MidiMessage>[];
    for (final message in messages) {
      switch (message) {
        case final MidiNoteOn noteOn when noteOn.isNoteOff:
          _noteOff(noteOn, noteOn.channel, noteOn.note, out);
        case final MidiNoteOn noteOn:
          _noteOn(noteOn, out);
        case final MidiNoteOff noteOff:
          _noteOff(noteOff, noteOff.channel, noteOff.note, out);
        case final MidiControlChange change when _endsNotes(change):
          _releaseChannel(change.channel, out);
          out.add(change);
        default:
          out.add(message);
      }
    }
    _send(out);
  }

  // ...........................................................................
  /// Sends a Note Off for [note] on [channel] when the note is held and
  /// frees its cell; sends nothing otherwise.
  void release({required int channel, required int note}) {
    final out = <MidiMessage>[];
    _release(_cell(channel, note), out);
    _send(out);
  }

  /// Sends a Note Off for every held note of [channel] and frees its
  /// cells.
  void releaseChannel(int channel) {
    assert(channel >= 0 && channel < channels);
    final out = <MidiMessage>[];
    _releaseChannel(channel, out);
    _send(out);
  }

  /// Sends a Note Off for every held note and empties the matrix.
  void releaseAll() {
    final out = <MidiMessage>[];
    for (final key in List.of(_activeNotes)) {
      _release(_cell(key.channel, key.note), out);
    }
    _send(out);
  }

  /// Empties the matrix without sending anything.
  void reset() {
    for (var cell = 0; cell < _counts.length; cell++) {
      if (_counts[cell] == 0) continue;
      _slots[cell].fillRange(0, _counts[cell], 0);
      _counts[cell] = 0;
    }
    _activeNotes.clear();
  }

  // ...........................................................................
  /// Whether a repeated Note On on [channel] is sent as Note Off plus
  /// Note On.
  ///
  /// When false, a note that already sounds is left alone until its last
  /// Note Off arrives. The default is true for every channel.
  bool retriggerRepeatedNoteOns(int channel) {
    assert(channel >= 0 && channel < channels);
    return _retrigger[channel];
  }

  /// Sets [retriggerRepeatedNoteOns] of [channel] to [value].
  void setRetriggerRepeatedNoteOns({
    required int channel,
    required bool value,
  }) {
    assert(channel >= 0 && channel < channels);
    _retrigger[channel] = value;
  }

  // ...........................................................................
  /// Whether at least one Note On holds [note] on [channel].
  bool isActive({required int channel, required int note}) =>
      _counts[_cell(channel, note)] > 0;

  /// The number of Note Ons that hold [note] on [channel].
  int count({required int channel, required int note}) =>
      _counts[_cell(channel, note)];

  /// The velocities of the Note Ons that hold [note] on [channel], in the
  /// order they arrived; empty when the note is not held.
  ///
  /// The list is an unmodifiable snapshot.
  List<int> velocities({required int channel, required int note}) {
    final cell = _cell(channel, note);
    return _slots[cell].sublist(0, _counts[cell]).asUnmodifiableView();
  }

  /// All slots of the cell of [note] on [channel]: the velocity of every
  /// Note On that holds the note, then 0 for every free slot.
  ///
  /// The list is an unmodifiable snapshot.
  List<int> slots({required int channel, required int note}) =>
      _slots[_cell(channel, note)].sublist(0).asUnmodifiableView();

  // ...........................................................................
  /// The cells that hold at least one note, in the order they became
  /// active.
  ///
  /// The list is a live, unmodifiable view.
  late final List<MidiKey> activeNotes = UnmodifiableListView(_activeNotes);

  /// Receives the messages the matrix sends on; null drops them.
  MidiMessageCallback? midiOut;

  /// The number of velocity slots every cell starts with.
  final int initialSlots;

  /// The number of Note Ons a cell counts at most; the slots of a cell
  /// never grow beyond it.
  final int maxSlots;

  // ...........................................................................
  /// The number of channels.
  static const int channels = 16;

  /// The number of notes per channel.
  static const int notes = 128;

  // ...........................................................................
  final List<Uint8List> _slots;
  final Uint32List _counts;
  final List<bool> _retrigger;
  final List<MidiKey> _activeNotes = [];

  int _cell(int channel, int note) {
    assert(channel >= 0 && channel < channels);
    assert(note >= 0 && note < notes);
    return channel * notes + note;
  }

  void _noteOn(MidiNoteOn message, List<MidiMessage> out) {
    final cell = _cell(message.channel, message.note);
    final count = _counts[cell];
    _write(cell, count, message.velocity);
    if (count == 0) {
      _activeNotes.add(MidiKey(channel: message.channel, note: message.note));
      out.add(message);
    } else if (_retrigger[message.channel]) {
      out.add(MidiNoteOff(channel: message.channel, note: message.note));
      out.add(message);
    }
  }

  /// Writes [velocity] into slot [count] of [cell] and counts it, growing
  /// the cell up to [maxSlots]; a full cell keeps its count and takes the
  /// velocity into the slot filled last.
  void _write(int cell, int count, int velocity) {
    var slots = _slots[cell];
    if (count == maxSlots) {
      slots[count - 1] = velocity;
      return;
    }
    if (count == slots.length) {
      slots = Uint8List(min(slots.length * 2, maxSlots))..setAll(0, slots);
      _slots[cell] = slots;
    }
    slots[count] = velocity;
    _counts[cell] = count + 1;
  }

  void _noteOff(
    MidiMessage message,
    int channel,
    int note,
    List<MidiMessage> out,
  ) {
    final cell = _cell(channel, note);
    final count = _counts[cell];
    if (count == 0) {
      out.add(message);
      return;
    }
    _slots[cell][count - 1] = 0;
    _counts[cell] = count - 1;
    if (count == 1) {
      _removeActive(channel, note);
      out.add(message);
    }
  }

  /// Releases every held note of [channel] into [out].
  void _releaseChannel(int channel, List<MidiMessage> out) {
    for (final key in List.of(_activeNotes)) {
      if (key.channel == channel) _release(_cell(channel, key.note), out);
    }
  }

  /// Frees [cell] and adds a Note Off to [out] when the cell holds a note.
  void _release(int cell, List<MidiMessage> out) {
    final count = _counts[cell];
    if (count == 0) return;
    _slots[cell].fillRange(0, count, 0);
    _counts[cell] = 0;
    final channel = cell ~/ notes;
    final note = cell % notes;
    _removeActive(channel, note);
    out.add(MidiNoteOff(channel: channel, note: note));
  }

  void _removeActive(int channel, int note) => _activeNotes.removeWhere(
    (active) => active.channel == channel && active.note == note,
  );

  /// Whether [change] is a channel mode message that ends the notes of
  /// its channel: All Sound Off, All Notes Off, Omni Off, Omni On, Mono On
  /// or Poly On (MIDI 1.0 Detailed Specification, channel mode messages).
  static bool _endsNotes(MidiControlChange change) =>
      change.controller == MidiControllers.allSoundOff ||
      change.controller >= MidiControllers.allNotesOff;

  void _send(List<MidiMessage> out) {
    if (out.isEmpty) return;
    midiOut?.call(out);
  }
}
