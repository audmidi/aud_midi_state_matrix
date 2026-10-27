# aud_midi_state_matrix

Matrices of the state a MIDI stream leaves behind: which notes sound on
which channel, with the velocity of every Note On that holds them, and
the current value of every controller. Both matrices hand the messages
they process to a `midiOut` callback, so they sit in a chain in front of
an output.

Part of the aud_midi family, see [aud_midi](https://github.com/audmidi/aud_midi).

## Goals

- Count how many Note Ons hold a note, so merged inputs release it only
  with the last Note Off
- Retrigger a repeated Note On, or leave the sounding note alone, per
  channel
- Keep the list of active notes ready without scanning the matrix
- Remember the last value of every controller per channel
- Pure Dart without I/O; the only dependency is `aud_midi_standard`

## State

- `MidiNoteMatrix`: 16 channels × 128 notes, velocity slots per cell
  (initially 5, doubled when full, at most 10), `midiIn` and `midiOut`,
  `retriggerRepeatedNoteOns` per channel, `activeNotes` as a list of
  `MidiKey`, `release`, `releaseChannel`, `releaseAll`, `reset`
- All Sound Off, All Notes Off and the mode messages that imply it
  (CC 120, 123 to 127) release the held notes of their channel
- `MidiControllerMatrix`: 16 channels × 128 controllers, the last value
  per cell, `midiIn` and `midiOut` pass-through, `value`, `set`,
  `entries` as a list of `MidiControlChange`, `reset`, `resetChannel`
- `midiOut` is a `MidiMessageCallback`; `MidiKey`, `MidiControlChange`
  and the callback type come from `aud_midi_standard`
- Not yet: Reset All Controllers (CC 121) in the controller matrix,
  14-bit controller pairs, RPN/NRPN, MIDI 2.0 messages
- 100 % test coverage

## Installation

```bash
dart pub add aud_midi_state_matrix
```

## Documentation

- [Plan of ticket aud_midi_02](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-27-aud_midi_02-track-active-notes.md)
- [Decision state-001: note cells are stacks of velocity slots](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/concepts/decisions/state-001.md)
- [Guides](doc/guides/)

## Code Examples

```dart
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
```

## How It Works

Every cell of `MidiNoteMatrix` is a stack of velocity slots. A Note On
writes its velocity into the first free slot, a Note Off frees the slot
filled last, so the number of occupied slots says how many Note Ons hold
the note. The rules towards `midiOut`, `n` being the occupied slots before
the message:

| Input | State | Retrigger on | Retrigger off |
| --- | --- | --- | --- |
| Note On | n = 0 | send the Note On | send the Note On |
| Note On | n ≥ 1 | Note Off (release 64), then the new Note On | nothing |
| Note Off | n ≥ 2 | nothing | nothing |
| Note Off | n = 1 | send the Note Off as received | same |
| Note Off | n = 0 | forward unchanged, so no note gets stuck | same |

A Note On with velocity 0 counts as Note Off. Every other message passes
through unchanged and in order. A cell counts at most `maxSlots` Note Ons
(default 10): a further Note On is sent by the rules above, but only
replaces the velocity of the slot filled last, so a stream of Note Ons
without Note Offs cannot grow the matrix.

A Note Off that never arrives would leave a note sounding forever. Three
things end such notes: All Sound Off, All Notes Off and the mode messages
that imply it (CC 120, 123 to 127) send a Note Off for every held note of
their channel before they pass through; `release`, `releaseChannel` and
`releaseAll` do the same on request, e.g. when a port disappears or the
app loses focus. `MidiControllerMatrix` records every Control Change and
passes all messages through, so both matrices chain.

## Contributing

See [doc/guides/develop-guide.md](doc/guides/develop-guide.md).
