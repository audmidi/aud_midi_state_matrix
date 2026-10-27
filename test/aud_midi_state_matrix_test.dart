// @license
// Copyright (c) audmidi
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_state_matrix/aud_midi_state_matrix.dart';
import 'package:test/test.dart' show expect, group, test;

void main() {
  group('AudMidiStateMatrix', () {
    test('greets with the greeting', () {
      expect(const AudMidiStateMatrix(greeting: 'Hi').greet('Ada'), 'Hi, Ada!');
    });

    test('example() greets with Hello', () {
      expect(AudMidiStateMatrix.example().greet('Ada'), 'Hello, Ada!');
      expect(AudMidiStateMatrix.example(greeting: 'Hey').greeting, 'Hey');
    });
  });
}
