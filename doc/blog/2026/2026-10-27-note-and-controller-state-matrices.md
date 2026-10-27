# Note and controller state matrices

## Motivation

- An instrument app that merges several inputs into one MIDI output needs
  to know which notes sound right now, how often each one is held and
  which controller values are current.
- Without that state, two inputs playing the same note end it with the
  first Note Off, repeated Note Ons stack up at the output, and a Note
  Off that never arrives leaves a note hanging forever.
- This package holds that state in two matrices and puts them into a
  chain in front of an output.

## Strategy

- `MidiNoteMatrix`: 16 channels × 128 notes, every cell a stack of
  velocity slots, one per Note On that holds the note.
- `MidiControllerMatrix`: 16 channels × 128 controllers with the last
  value of each.
- Both take messages through `midiIn` and hand what results to a
  `MidiMessageCallback`, so they sit anywhere between inputs and outputs.
- Pure Dart, no I/O; the only dependency is `aud_midi_standard`.
- Every rule of the design is a test; coverage is 100 % per file.

## Implementation 1: the note matrix

- A Note On writes its velocity into the first free slot of its cell, a
  Note Off frees the slot filled last; the count of occupied slots says
  how many Note Ons hold the note.
- Towards the output only the first Note On and the last Note Off pass.
  A repeated Note On sends a Note Off and the new Note On while
  `retriggerRepeatedNoteOns` is true for the channel, and nothing while
  it is false. A Note On with velocity 0 counts as Note Off, a Note Off
  of a silent note passes through, every other message passes through
  unchanged and in order.
- `activeNotes` lists the cells that hold a note as `MidiKey`, in the
  order they became active; `velocities`, `slots`, `count` and
  `isActive` read a cell.
- Cells start with five slots and double them when full, up to
  `maxSlots` (default 10). A full cell counts no further Note On; the
  newest velocity replaces the slot filled last, so a stream of Note Ons
  without Note Offs cannot grow the matrix.

## Implementation 2: ending notes whose Note Off never comes

- `release(channel:, note:)`, `releaseChannel(channel)` and
  `releaseAll()` send a Note Off for every held note in their scope and
  free the cells; `reset()` clears silently.
- All Sound Off, All Notes Off and the mode messages that imply All Notes
  Off (CC 120, 123 to 127) release the held notes of their channel and
  pass through after the Note Offs. CC 121 and 122 leave the notes alone.

## Implementation 3: the controller matrix

- `midiIn` records every Control Change and passes all messages through
  unchanged, in one call per batch, as a copy of the list.
- `value` answers the last value or null, `isSet` whether one is known,
  `set` records without sending, `reset` and `resetChannel` forget.
- `entries` lists the known values as `MidiControlChange` messages in the
  order their cells were first set, ready to be sent to restore a state.

## Implementation 4: example and documentation

- The example chains the note matrix, the controller matrix and a
  printing output and plays the scenario of two Note Ons and two Note
  Offs with and without retrigger.
- The READMEs in English and German explain the sending rules as a table
  and the ways to end stuck notes; the `index.jsonc` names both matrices
  and the types used from `aud_midi_standard`.

## Dependency updates

- `aud_midi_standard` 0.2.0 provides `MidiKey` for the active list and
  `MidiMessageCallback` for `midiOut`; the entries of the controller
  matrix are its `MidiControlChange`.
- The DNA layer `dna_audanika` 0.1.0 brings the blog and translate guides
  this post follows, a prompt hook and a README check script.

## Open Points

- Remember the source of every held note, so that a vanished port or
  touch session releases only its own notes (`releaseSource`).
- An optional time limit driven by the app (`sweep(now)`, `maxHold` per
  channel).
- Reset All Controllers (CC 121) in the controller matrix, 14-bit
  controller pairs, RPN/NRPN and MIDI 2.0 messages.
