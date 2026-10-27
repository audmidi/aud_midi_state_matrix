// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:aud_midi_state_matrix/aud_midi_state_matrix.dart';
import 'package:test/test.dart';

void main() {
  group('MidiControllerMatrix', () {
    late MidiControllerMatrix matrix;
    late List<List<MidiMessage>> sent;

    setUp(() {
      sent = [];
      matrix = MidiControllerMatrix(midiOut: sent.add);
    });

    const mod100 = MidiControlChange(channel: 0, controller: 1, value: 100);
    const mod20 = MidiControlChange(channel: 0, controller: 1, value: 20);
    const sustain = MidiControlChange(channel: 5, controller: 64, value: 127);

    // .........................................................................
    group('constructor', () {
      test('starts without values', () {
        expect(matrix.value(channel: 0, controller: 1), isNull);
        expect(matrix.isSet(channel: 0, controller: 1), isFalse);
        expect(matrix.entries, isEmpty);
        expect(matrix.midiOut, isNotNull);
        expect(MidiControllerMatrix().midiOut, isNull);
      });

      test('has 16 channels and 128 controllers', () {
        expect(MidiControllerMatrix.channels, 16);
        expect(MidiControllerMatrix.controllers, 128);
        expect(matrix.value(channel: 15, controller: 127), isNull);
      });
    });

    // .........................................................................
    group('midiIn(messages)', () {
      test('records the last value of every Control Change', () {
        matrix.midiIn([mod100, sustain, mod20]);
        expect(matrix.value(channel: 0, controller: 1), 20);
        expect(matrix.value(channel: 5, controller: 64), 127);
        expect(matrix.isSet(channel: 0, controller: 1), isTrue);
        expect(matrix.value(channel: 1, controller: 1), isNull);
        expect(
          matrix.entries,
          equals([
            const MidiControlChange(channel: 0, controller: 1, value: 20),
            const MidiControlChange(channel: 5, controller: 64, value: 127),
          ]),
        );
      });

      test('passes every message through unchanged and in order', () {
        const noteOn = MidiNoteOn(channel: 0, note: 60, velocity: 100);
        matrix.midiIn([noteOn, mod100]);
        matrix.midiIn([]);
        expect(
          sent,
          equals([
            <MidiMessage>[noteOn, mod100],
          ]),
        );
      });

      test('hands a copy of the list to midiOut', () {
        final input = <MidiMessage>[mod100];
        matrix.midiIn(input);
        expect(identical(sent.single, input), isFalse);
        sent.single.clear();
        expect(input, equals([mod100]));
      });

      test('works without midiOut', () {
        final silent = MidiControllerMatrix()..midiIn([mod100]);
        expect(silent.value(channel: 0, controller: 1), 100);
        silent.midiOut = sent.add;
        silent.midiIn([mod20]);
        expect(
          sent,
          equals([
            <MidiMessage>[mod20],
          ]),
        );
      });
    });

    // .........................................................................
    group('set(channel, controller, value)', () {
      test('records a value without sending', () {
        matrix.set(channel: 2, controller: 7, value: 9);
        expect(matrix.value(channel: 2, controller: 7), 9);
        expect(
          matrix.entries,
          equals([
            const MidiControlChange(channel: 2, controller: 7, value: 9),
          ]),
        );
        expect(sent, isEmpty);
      });

      test('asserts the ranges', () {
        for (final (channel, controller, value) in [
          (-1, 0, 0),
          (16, 0, 0),
          (0, -1, 0),
          (0, 128, 0),
          (0, 0, -1),
          (0, 0, 128),
        ]) {
          expect(
            () => matrix.set(
              channel: channel,
              controller: controller,
              value: value,
            ),
            throwsA(isA<AssertionError>()),
            reason: 'channel $channel, controller $controller, value $value',
          );
        }
      });
    });

    // .........................................................................
    group('value(channel, controller) and isSet(channel, controller)', () {
      test('assert the ranges', () {
        for (final (channel, controller) in [
          (-1, 0),
          (16, 0),
          (0, -1),
          (0, 128),
        ]) {
          expect(
            () => matrix.value(channel: channel, controller: controller),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => matrix.isSet(channel: channel, controller: controller),
            throwsA(isA<AssertionError>()),
          );
        }
      });
    });

    // .........................................................................
    group('entries', () {
      test('lists the cells in the order they were first set', () {
        matrix.set(channel: 1, controller: 1, value: 1);
        matrix.set(channel: 0, controller: 0, value: 2);
        matrix.set(channel: 1, controller: 1, value: 3);
        expect(
          matrix.entries,
          equals([
            const MidiControlChange(channel: 1, controller: 1, value: 3),
            const MidiControlChange(channel: 0, controller: 0, value: 2),
          ]),
        );
      });

      test('is an unmodifiable snapshot', () {
        matrix.set(channel: 1, controller: 1, value: 1);
        final entries = matrix.entries;
        matrix.set(channel: 1, controller: 1, value: 2);
        expect(entries.single.value, 1);
        expect(() => entries.clear(), throwsUnsupportedError);
      });
    });

    // .........................................................................
    group('reset()', () {
      test('forgets all values', () {
        matrix.midiIn([mod100, sustain]);
        matrix.reset();
        expect(matrix.value(channel: 0, controller: 1), isNull);
        expect(matrix.value(channel: 5, controller: 64), isNull);
        expect(matrix.entries, isEmpty);
        matrix.midiIn([mod20]);
        expect(
          matrix.entries,
          equals([
            const MidiControlChange(channel: 0, controller: 1, value: 20),
          ]),
        );
      });
    });

    // .........................................................................
    group('resetChannel(channel)', () {
      test('forgets the values of one channel', () {
        matrix.midiIn([mod100, sustain]);
        matrix.resetChannel(5);
        expect(matrix.value(channel: 5, controller: 64), isNull);
        expect(matrix.value(channel: 0, controller: 1), 100);
        expect(
          matrix.entries,
          equals([
            const MidiControlChange(channel: 0, controller: 1, value: 100),
          ]),
        );
      });

      test('asserts the channel range', () {
        for (final channel in [-1, 16]) {
          expect(
            () => matrix.resetChannel(channel),
            throwsA(isA<AssertionError>()),
          );
        }
      });
    });
  });
}
