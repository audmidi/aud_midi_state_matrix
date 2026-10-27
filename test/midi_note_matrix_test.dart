// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:aud_midi_state_matrix/aud_midi_state_matrix.dart';
import 'package:test/test.dart';

void main() {
  group('MidiNoteMatrix', () {
    late MidiNoteMatrix matrix;
    late List<List<MidiMessage>> sent;

    setUp(() {
      sent = [];
      matrix = MidiNoteMatrix(midiOut: sent.add);
    });

    const on50 = MidiNoteOn(channel: 9, note: 67, velocity: 50);
    const on60 = MidiNoteOn(channel: 9, note: 67, velocity: 60);
    const off = MidiNoteOff(channel: 9, note: 67);
    const offRelease = MidiNoteOff(channel: 9, note: 67, velocity: 10);
    const active = MidiKey(channel: 9, note: 67);

    // .........................................................................
    group('constructor', () {
      test('starts empty with five slots per cell', () {
        expect(matrix.initialSlots, 5);
        expect(matrix.maxSlots, 10);
        expect(matrix.activeNotes, isEmpty);
        expect(matrix.slots(channel: 9, note: 67), equals([0, 0, 0, 0, 0]));
        expect(matrix.velocities(channel: 9, note: 67), isEmpty);
        expect(matrix.count(channel: 9, note: 67), 0);
        expect(matrix.isActive(channel: 9, note: 67), isFalse);
        expect(matrix.midiOut, isNotNull);
        for (var channel = 0; channel < MidiNoteMatrix.channels; channel++) {
          expect(matrix.retriggerRepeatedNoteOns(channel), isTrue);
        }
      });

      test('takes the number of initial and maximal slots', () {
        final small = MidiNoteMatrix(initialSlots: 2, maxSlots: 3);
        expect(small.initialSlots, 2);
        expect(small.maxSlots, 3);
        expect(small.slots(channel: 0, note: 0), equals([0, 0]));
        expect(small.midiOut, isNull);
        expect(
          () => MidiNoteMatrix(initialSlots: 0),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => MidiNoteMatrix(initialSlots: 5, maxSlots: 4),
          throwsA(isA<AssertionError>()),
        );
      });

      test('has 16 channels and 128 notes', () {
        expect(MidiNoteMatrix.channels, 16);
        expect(MidiNoteMatrix.notes, 128);
        expect(matrix.slots(channel: 15, note: 127), hasLength(5));
      });
    });

    // .........................................................................
    group('midiIn(messages)', () {
      test('writes a Note On into the first free slot', () {
        matrix.midiIn([on50]);
        expect(matrix.slots(channel: 9, note: 67), equals([50, 0, 0, 0, 0]));
        matrix.midiIn([on60]);
        expect(matrix.slots(channel: 9, note: 67), equals([50, 60, 0, 0, 0]));
        expect(matrix.velocities(channel: 9, note: 67), equals([50, 60]));
        expect(matrix.count(channel: 9, note: 67), 2);
        expect(matrix.isActive(channel: 9, note: 67), isTrue);
        expect(matrix.activeNotes, equals([active]));
      });

      test('frees the slot filled last on a Note Off', () {
        matrix.midiIn([on50, on60, off]);
        expect(matrix.slots(channel: 9, note: 67), equals([50, 0, 0, 0, 0]));
        expect(matrix.count(channel: 9, note: 67), 1);
        expect(matrix.activeNotes, equals([active]));
        matrix.midiIn([off]);
        expect(matrix.slots(channel: 9, note: 67), equals([0, 0, 0, 0, 0]));
        expect(matrix.isActive(channel: 9, note: 67), isFalse);
        expect(matrix.activeNotes, isEmpty);
      });

      test('doubles the slots of a full cell', () {
        matrix.midiIn([
          for (var velocity = 1; velocity <= 6; velocity++)
            MidiNoteOn(channel: 9, note: 67, velocity: velocity),
        ]);
        expect(
          matrix.slots(channel: 9, note: 67),
          equals([1, 2, 3, 4, 5, 6, 0, 0, 0, 0]),
        );
        expect(matrix.count(channel: 9, note: 67), 6);
        expect(matrix.velocities(channel: 9, note: 67), hasLength(6));
        expect(matrix.slots(channel: 9, note: 68), hasLength(5));
        matrix.midiIn([for (var i = 0; i < 6; i++) off]);
        expect(matrix.slots(channel: 9, note: 67), equals(List.filled(10, 0)));
      });

      test('treats a Note On with velocity 0 as Note Off', () {
        const on0 = MidiNoteOn(channel: 9, note: 67, velocity: 0);
        matrix.midiIn([on50, on0]);
        expect(matrix.isActive(channel: 9, note: 67), isFalse);
        expect(
          sent,
          equals([
            <MidiMessage>[on50, on0],
          ]),
        );
      });

      test('keeps the cells apart by channel and note', () {
        const other = MidiNoteOn(channel: 10, note: 67, velocity: 70);
        const third = MidiNoteOn(channel: 9, note: 68, velocity: 80);
        matrix.midiIn([on50, other, third]);
        expect(matrix.velocities(channel: 9, note: 67), equals([50]));
        expect(matrix.velocities(channel: 10, note: 67), equals([70]));
        expect(matrix.velocities(channel: 9, note: 68), equals([80]));
        expect(
          matrix.activeNotes,
          equals([
            active,
            const MidiKey(channel: 10, note: 67),
            const MidiKey(channel: 9, note: 68),
          ]),
        );
        matrix.midiIn([const MidiNoteOff(channel: 10, note: 67)]);
        expect(
          matrix.activeNotes,
          equals([active, const MidiKey(channel: 9, note: 68)]),
        );
        expect(matrix.velocities(channel: 9, note: 67), equals([50]));
      });

      test('passes other messages through unchanged and in order', () {
        const change = MidiControlChange(channel: 9, controller: 1, value: 3);
        const bend = MidiPitchBend(channel: 9, value: 8192);
        matrix.midiIn([change, on50, bend, on60, change]);
        expect(
          sent,
          equals([
            <MidiMessage>[change, on50, bend, off, on60, change],
          ]),
        );
      });

      test('does not call midiOut when no message results', () {
        matrix.midiIn([]);
        matrix.setRetriggerRepeatedNoteOns(channel: 9, value: false);
        matrix.midiIn([on50]);
        matrix.midiIn([on60]);
        matrix.midiIn([off]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
          ]),
        );
      });

      test('works without midiOut', () {
        final silent = MidiNoteMatrix();
        silent.midiIn([on50, on60, off, off]);
        expect(silent.activeNotes, isEmpty);
        silent.midiOut = sent.add;
        silent.midiIn([on50]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
          ]),
        );
      });
    });

    // .........................................................................
    group('channel mode messages', () {
      const other = MidiNoteOn(channel: 9, note: 68, velocity: 70);
      const foreign = MidiNoteOn(channel: 0, note: 67, velocity: 80);
      MidiControlChange mode(int controller, {int channel = 9}) =>
          MidiControlChange(channel: channel, controller: controller, value: 0);

      test('release the held notes of the channel and pass through', () {
        for (final controller in [120, 123, 124, 125, 126, 127]) {
          matrix.reset();
          sent.clear();
          matrix.midiIn([on50, other, foreign, mode(controller)]);
          expect(
            sent.single,
            equals([
              on50,
              other,
              foreign,
              off,
              const MidiNoteOff(channel: 9, note: 68),
              mode(controller),
            ]),
            reason: 'controller $controller',
          );
          expect(
            matrix.activeNotes,
            equals([const MidiKey(channel: 0, note: 67)]),
          );
          expect(matrix.slots(channel: 9, note: 67), equals(List.filled(5, 0)));
        }
      });

      test('pass through without held notes', () {
        matrix.midiIn([mode(123)]);
        expect(
          sent,
          equals([
            <MidiMessage>[mode(123)],
          ]),
        );
      });

      test('leave the notes alone for other controllers', () {
        matrix.midiIn([on50, mode(121), mode(122), mode(64)]);
        expect(sent.single, equals([on50, mode(121), mode(122), mode(64)]));
        expect(matrix.isActive(channel: 9, note: 67), isTrue);
      });
    });

    // .........................................................................
    group('release(channel: channel, note: note)', () {
      test('sends a Note Off for a held note and frees the cell', () {
        matrix.midiIn([on50, on60]);
        sent.clear();
        matrix.release(channel: 9, note: 67);
        expect(
          sent,
          equals([
            <MidiMessage>[off],
          ]),
        );
        expect(matrix.activeNotes, isEmpty);
        expect(matrix.slots(channel: 9, note: 67), equals(List.filled(5, 0)));
      });

      test('sends nothing for a note that is not held', () {
        matrix.release(channel: 9, note: 67);
        expect(sent, isEmpty);
      });

      test('asserts the channel and note ranges', () {
        for (final (channel, note) in [(-1, 0), (16, 0), (0, -1), (0, 128)]) {
          expect(
            () => matrix.release(channel: channel, note: note),
            throwsA(isA<AssertionError>()),
          );
        }
      });
    });

    // .........................................................................
    group('releaseChannel(channel)', () {
      test('sends a Note Off for every held note of the channel', () {
        const other = MidiNoteOn(channel: 9, note: 68, velocity: 70);
        const foreign = MidiNoteOn(channel: 0, note: 67, velocity: 80);
        matrix.midiIn([on50, other, foreign]);
        sent.clear();
        matrix.releaseChannel(9);
        expect(
          sent,
          equals([
            <MidiMessage>[off, const MidiNoteOff(channel: 9, note: 68)],
          ]),
        );
        expect(
          matrix.activeNotes,
          equals([const MidiKey(channel: 0, note: 67)]),
        );
        expect(matrix.velocities(channel: 0, note: 67), equals([80]));
      });

      test('sends nothing when the channel holds no note', () {
        matrix.releaseChannel(9);
        expect(sent, isEmpty);
      });

      test('asserts the channel range', () {
        for (final channel in [-1, 16]) {
          expect(
            () => matrix.releaseChannel(channel),
            throwsA(isA<AssertionError>()),
          );
        }
      });
    });

    // .........................................................................
    group('maxSlots', () {
      List<MidiNoteOn> noteOns(int count) => [
        for (var velocity = 1; velocity <= count; velocity++)
          MidiNoteOn(channel: 9, note: 67, velocity: velocity),
      ];

      test('caps the Note Ons of a cell and keeps the newest velocity', () {
        matrix.midiIn(noteOns(11));
        expect(
          matrix.slots(channel: 9, note: 67),
          equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 11]),
        );
        expect(matrix.count(channel: 9, note: 67), 10);
        expect(matrix.activeNotes, equals([active]));
        matrix.midiIn(noteOns(100));
        expect(matrix.slots(channel: 9, note: 67), hasLength(10));
        expect(matrix.count(channel: 9, note: 67), 10);
      });

      test('still sends every Note On by the retrigger rule', () {
        final ons = noteOns(11);
        matrix.midiIn(ons);
        expect(
          sent.single,
          equals([
            ons.first,
            for (final on in ons.skip(1)) ...[off, on],
          ]),
        );
        sent.clear();
        matrix.setRetriggerRepeatedNoteOns(channel: 9, value: false);
        matrix.midiIn(noteOns(3));
        expect(sent, isEmpty);
        expect(matrix.slots(channel: 9, note: 67).last, 3);
      });

      test('releases a capped cell after maxSlots Note Offs', () {
        matrix.midiIn(noteOns(12));
        sent.clear();
        matrix.midiIn([for (var i = 0; i < 9; i++) off]);
        expect(sent, isEmpty);
        expect(matrix.count(channel: 9, note: 67), 1);
        matrix.midiIn([off]);
        expect(
          sent,
          equals([
            <MidiMessage>[off],
          ]),
        );
        expect(matrix.activeNotes, isEmpty);
        matrix.midiIn([off]);
        expect(sent, hasLength(2));
      });

      test('grows to maxSlots when doubling would exceed it', () {
        final small = MidiNoteMatrix(initialSlots: 3, maxSlots: 4);
        small.midiIn(noteOns(5));
        expect(small.slots(channel: 9, note: 67), equals([1, 2, 3, 5]));
        expect(small.count(channel: 9, note: 67), 4);
      });

      test('never grows when initialSlots equals maxSlots', () {
        final fixed = MidiNoteMatrix(initialSlots: 2, maxSlots: 2);
        fixed.midiIn(noteOns(3));
        expect(fixed.slots(channel: 9, note: 67), equals([1, 3]));
        expect(fixed.count(channel: 9, note: 67), 2);
      });
    });

    // .........................................................................
    group('sending with retriggerRepeatedNoteOns true', () {
      test('sends the first Note On', () {
        matrix.midiIn([on50]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
          ]),
        );
      });

      test('sends a Note Off and the Note On for a repeated Note On', () {
        matrix.midiIn([on50]);
        matrix.midiIn([on60]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
            <MidiMessage>[off, on60],
          ]),
        );
        expect(off.velocity, 64);
      });

      test('sends nothing for a Note Off that leaves the note held', () {
        matrix.midiIn([on50, on60]);
        sent.clear();
        matrix.midiIn([off]);
        expect(sent, isEmpty);
        expect(matrix.count(channel: 9, note: 67), 1);
      });

      test('sends the last Note Off as received', () {
        matrix.midiIn([on50, on60, off]);
        sent.clear();
        matrix.midiIn([offRelease]);
        expect(
          sent,
          equals([
            <MidiMessage>[offRelease],
          ]),
        );
      });

      test('forwards a Note Off of a note that is not held', () {
        matrix.midiIn([off]);
        expect(
          sent,
          equals([
            <MidiMessage>[off],
          ]),
        );
        expect(matrix.activeNotes, isEmpty);
        expect(matrix.slots(channel: 9, note: 67), equals([0, 0, 0, 0, 0]));
      });

      test('plays the example of the plan', () {
        matrix.midiIn([on50]);
        matrix.midiIn([on60]);
        matrix.midiIn([off]);
        matrix.midiIn([off]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
            <MidiMessage>[off, on60],
            <MidiMessage>[off],
          ]),
        );
        expect(matrix.activeNotes, isEmpty);
      });
    });

    // .........................................................................
    group('sending with retriggerRepeatedNoteOns false', () {
      setUp(() {
        matrix.setRetriggerRepeatedNoteOns(channel: 9, value: false);
      });

      test('sends a sounding note only once', () {
        matrix.midiIn([on50]);
        matrix.midiIn([on60]);
        matrix.midiIn([off]);
        matrix.midiIn([off]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
            <MidiMessage>[off],
          ]),
        );
        expect(matrix.activeNotes, isEmpty);
      });

      test('still counts every Note On', () {
        matrix.midiIn([on50, on60]);
        expect(matrix.velocities(channel: 9, note: 67), equals([50, 60]));
      });

      test('applies per channel', () {
        const on10 = MidiNoteOn(channel: 10, note: 67, velocity: 50);
        matrix.midiIn([on10, on10]);
        expect(
          sent,
          equals([
            <MidiMessage>[on10, const MidiNoteOff(channel: 10, note: 67), on10],
          ]),
        );
      });
    });

    // .........................................................................
    group('retriggerRepeatedNoteOns(channel)', () {
      test('is set per channel', () {
        matrix.setRetriggerRepeatedNoteOns(channel: 3, value: false);
        expect(matrix.retriggerRepeatedNoteOns(3), isFalse);
        expect(matrix.retriggerRepeatedNoteOns(4), isTrue);
        matrix.setRetriggerRepeatedNoteOns(channel: 3, value: true);
        expect(matrix.retriggerRepeatedNoteOns(3), isTrue);
      });

      test('asserts the channel range', () {
        for (final channel in [-1, 16]) {
          expect(
            () => matrix.retriggerRepeatedNoteOns(channel),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => matrix.setRetriggerRepeatedNoteOns(
              channel: channel,
              value: false,
            ),
            throwsA(isA<AssertionError>()),
          );
        }
      });
    });

    // .........................................................................
    group('activeNotes', () {
      test('is a live, unmodifiable view', () {
        final view = matrix.activeNotes;
        matrix.midiIn([on50]);
        expect(view, equals([active]));
        expect(identical(view, matrix.activeNotes), isTrue);
        expect(() => view.clear(), throwsUnsupportedError);
      });
    });

    // .........................................................................
    group('velocities(channel, note) and slots(channel, note)', () {
      test('return unmodifiable snapshots', () {
        matrix.midiIn([on50]);
        final velocities = matrix.velocities(channel: 9, note: 67);
        final slots = matrix.slots(channel: 9, note: 67);
        matrix.midiIn([on60]);
        expect(velocities, equals([50]));
        expect(slots, equals([50, 0, 0, 0, 0]));
        expect(() => velocities[0] = 1, throwsUnsupportedError);
        expect(() => slots[0] = 1, throwsUnsupportedError);
      });

      test('assert the channel and note ranges', () {
        for (final (channel, note) in [(-1, 0), (16, 0), (0, -1), (0, 128)]) {
          expect(
            () => matrix.velocities(channel: channel, note: note),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => matrix.slots(channel: channel, note: note),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => matrix.count(channel: channel, note: note),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => matrix.isActive(channel: channel, note: note),
            throwsA(isA<AssertionError>()),
          );
        }
      });
    });

    // .........................................................................
    group('reset()', () {
      test('empties the matrix without sending', () {
        const other = MidiNoteOn(channel: 0, note: 1, velocity: 2);
        matrix.midiIn([on50, on60, other]);
        sent.clear();
        matrix.reset();
        expect(sent, isEmpty);
        expect(matrix.activeNotes, isEmpty);
        expect(matrix.slots(channel: 9, note: 67), equals([0, 0, 0, 0, 0]));
        expect(matrix.count(channel: 0, note: 1), 0);
        matrix.midiIn([on50]);
        expect(
          sent,
          equals([
            <MidiMessage>[on50],
          ]),
        );
      });
    });

    // .........................................................................
    group('releaseAll()', () {
      test('sends a Note Off for every active note and empties', () {
        const other = MidiNoteOn(channel: 0, note: 1, velocity: 2);
        matrix.midiIn([on50, on60, other]);
        sent.clear();
        matrix.releaseAll();
        expect(
          sent,
          equals([
            <MidiMessage>[off, const MidiNoteOff(channel: 0, note: 1)],
          ]),
        );
        expect(matrix.activeNotes, isEmpty);
        expect(matrix.slots(channel: 9, note: 67), equals([0, 0, 0, 0, 0]));
        expect(matrix.isActive(channel: 0, note: 1), isFalse);
      });

      test('sends nothing when no note is active', () {
        matrix.releaseAll();
        expect(sent, isEmpty);
      });
    });
  });
}
