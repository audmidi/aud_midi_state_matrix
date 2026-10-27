# Changelog

## Unreleased

### Added

- Add the initial version
- Add MidiNoteMatrix and MidiControllerMatrix
  - MidiNoteMatrix: velocity slots per channel and note, midiOut callback,
    retrigger per channel, active notes as MidiKey
  - MidiControllerMatrix: last value of every controller per channel,
    entries as MidiControlChange, pass-through to midiOut
  - Example, README in English and German, index.jsonc
