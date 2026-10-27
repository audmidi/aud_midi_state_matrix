// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// Matrices of the state a MIDI stream leaves behind: the notes that sound
/// per channel and note with the velocity of every Note On that holds them,
/// and the current value of every controller per channel. Both matrices
/// hand the messages they process to a `MidiMessageCallback`, so they can
/// sit in a chain in front of an output. The entries they list are the
/// `MidiKey` and `MidiControlChange` of `aud_midi_standard`.
library;

export 'src/midi_controller_matrix.dart';
export 'src/midi_note_matrix.dart';
