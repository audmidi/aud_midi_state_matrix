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

### Changed

- Cap the slots of a cell and release stuck notes

MidiNoteMatrix grows a cell up to maxSlots (default 10); a full cell takes the newest velocity into the slot filled last
release and releaseChannel end held notes on request
All Sound Off, All Notes Off and the mode messages that imply it release the held notes of their channel and pass through
README and index.jsonc describe the cap and the release paths
