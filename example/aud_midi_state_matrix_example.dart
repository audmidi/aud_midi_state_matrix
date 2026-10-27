#!/usr/bin/env dart

// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:aud_midi_state_matrix/aud_midi_state_matrix.dart';

void main() {
  // A chain: note matrix -> controller matrix -> output
  final controllers = MidiControllerMatrix(
    midiOut: (messages) => print('out: $messages'),
  );
  final notes = MidiNoteMatrix(midiOut: controllers.midiIn);

  const on50 = MidiNoteOn(channel: 9, note: 67, velocity: 50);
  const on60 = MidiNoteOn(channel: 9, note: 67, velocity: 60);
  const off = MidiNoteOff(channel: 9, note: 67);

  // Two Note Ons hold the note, only the last Note Off releases it.
  notes.midiIn([on50]); // out: the Note On
  notes.midiIn([on60]); // out: a Note Off, then the new Note On
  print(notes.slots(channel: 9, note: 67)); // [50, 60, 0, 0, 0]
  print(notes.activeNotes); // [MidiKey(channel: 9, note: 67)]
  notes.midiIn([off]); // nothing, the note is still held
  notes.midiIn([off]); // out: the Note Off

  // Without retrigger a sounding note is left alone.
  notes.setRetriggerRepeatedNoteOns(channel: 9, value: false);
  notes.midiIn([on50, on60, off, off]); // out: the Note On, the Note Off

  // Controller values are remembered on the way through.
  notes.midiIn([
    const MidiControlChange(channel: 9, controller: 1, value: 100),
  ]);
  print(controllers.value(channel: 9, controller: 1)); // 100
  print(controllers.entries);
}
