// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:typed_data';

import 'package:aud_midi_standard/aud_midi_standard.dart';

// #############################################################################
/// The current value of every controller, per channel and controller.
///
/// The matrix has [channels] × [controllers] cells. Every cell holds the
/// value of the last Control Change that reached it, or nothing until one
/// did. Messages enter through [midiIn]: Control Changes update the
/// matrix, and every message passes through [midiOut] unchanged and in
/// order, so the matrix can sit in a chain in front of an output.
///
/// Channel mode messages (controllers 120 to 127) are stored like any
/// other value; the matrix does not interpret them. Channels and
/// controllers are 0-based. Arguments outside their ranges fail an
/// assertion in debug builds.
final class MidiControllerMatrix {
  /// Creates an empty matrix.
  ///
  /// - [midiOut] receives every message that enters; may be set later.
  MidiControllerMatrix({this.midiOut})
    : _values = Int16List(channels * controllers)
        ..fillRange(0, channels * controllers, _unset);

  // ...........................................................................
  /// Records every Control Change in [messages] and hands all messages to
  /// [midiOut] unchanged and in order, in one call.
  ///
  /// [midiOut] receives a copy of [messages]; it is not called for an
  /// empty list.
  void midiIn(List<MidiMessage> messages) {
    for (final message in messages) {
      if (message is MidiControlChange) {
        _set(message.channel, message.controller, message.value);
      }
    }
    if (messages.isEmpty) return;
    midiOut?.call(List.of(messages));
  }

  // ...........................................................................
  /// The value of [controller] on [channel], or null when no value was
  /// set yet.
  int? value({required int channel, required int controller}) {
    final value = _values[_cell(channel, controller)];
    return value == _unset ? null : value;
  }

  /// Whether a value of [controller] on [channel] is known.
  bool isSet({required int channel, required int controller}) =>
      _values[_cell(channel, controller)] != _unset;

  /// Records [value] for [controller] on [channel] without sending
  /// anything.
  void set({
    required int channel,
    required int controller,
    required int value,
  }) {
    assert(value >= 0 && value <= 127);
    _set(channel, controller, value);
  }

  // ...........................................................................
  /// Forgets all values.
  void reset() {
    _values.fillRange(0, _values.length, _unset);
    _known.clear();
  }

  /// Forgets the values of [channel].
  void resetChannel(int channel) {
    assert(channel >= 0 && channel < channels);
    final start = channel * controllers;
    _values.fillRange(start, start + controllers, _unset);
    _known.removeWhere((cell) => cell ~/ controllers == channel);
  }

  // ...........................................................................
  /// The known values, in the order their cells were first set.
  ///
  /// The list is an unmodifiable snapshot.
  List<MidiControlChange> get entries => List.unmodifiable([
    for (final cell in _known)
      MidiControlChange(
        channel: cell ~/ controllers,
        controller: cell % controllers,
        value: _values[cell],
      ),
  ]);

  /// Receives every message that enters through [midiIn]; null drops
  /// them.
  MidiMessageCallback? midiOut;

  // ...........................................................................
  /// The number of channels.
  static const int channels = 16;

  /// The number of controllers per channel.
  static const int controllers = 128;

  // ...........................................................................
  static const int _unset = -1;

  final Int16List _values;
  final List<int> _known = [];

  int _cell(int channel, int controller) {
    assert(channel >= 0 && channel < channels);
    assert(controller >= 0 && controller < controllers);
    return channel * controllers + controller;
  }

  void _set(int channel, int controller, int value) {
    final cell = _cell(channel, controller);
    if (_values[cell] == _unset) _known.add(cell);
    _values[cell] = value;
  }
}
