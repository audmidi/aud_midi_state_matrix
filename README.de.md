# aud_midi_state_matrix

Matrizen für den Zustand, den ein MIDI-Strom hinterlässt: welche Noten auf
welchem Kanal klingen, mit der Velocity jedes NoteOns, das sie hält, und
der aktuelle Wert jedes Controllers. Beide Matrizen reichen die
verarbeiteten Nachrichten an einen `midiOut`-Callback weiter und stehen so
in einer Kette vor einem Ausgang.

Teil der aud_midi-Familie, siehe [aud_midi](https://github.com/audmidi/aud_midi).

## Ziele

- Zählen, wie viele NoteOns eine Note halten, damit zusammengeführte
  Eingänge sie erst mit dem letzten NoteOff loslassen
- Ein wiederholtes NoteOn neu anschlagen oder den klingenden Ton in Ruhe
  lassen, pro Kanal
- Die Liste der aktiven Noten bereithalten, ohne die Matrix zu durchsuchen
- Den letzten Wert jedes Controllers pro Kanal merken
- Reines Dart ohne I/O; einzige Abhängigkeit ist `aud_midi_standard`

## Stand

- `MidiNoteMatrix`: 16 Kanäle × 128 Noten, Velocity-Slots pro Zelle
  (anfangs 5, bei Bedarf verdoppelt, höchstens 10), `midiIn` und `midiOut`,
  `retriggerRepeatedNoteOns` pro Kanal, `activeNotes` als Liste von
  `MidiKey`, `release`, `releaseChannel`, `releaseAll`, `reset`
- All Sound Off, All Notes Off und die Mode-Nachrichten, die es
  einschließen (CC 120, 123 bis 127), lassen die gehaltenen Noten ihres
  Kanals los
- `MidiControllerMatrix`: 16 Kanäle × 128 Controller, der letzte Wert pro
  Zelle, `midiIn` und `midiOut` als Durchleitung, `value`, `set`,
  `entries` als Liste von `MidiControlChange`, `reset`, `resetChannel`
- `midiOut` ist ein `MidiMessageCallback`; `MidiKey`, `MidiControlChange`
  und der Callback-Typ kommen aus `aud_midi_standard`
- Noch nicht: Reset All Controllers (CC 121) in der Controller-Matrix,
  14-Bit-Controller-Paare, RPN/NRPN, MIDI-2.0-Nachrichten
- 100 % Testabdeckung

## Installation

```bash
dart pub add aud_midi_state_matrix
```

## Dokumentation

- [Plan des Tickets aud_midi_02](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/tickets/2026-10-27-aud_midi_02-track-active-notes.md)
- [Entscheidung state-001: Notenzellen sind Stapel von Velocity-Slots](https://github.com/audmidi/aud_midi_pm/blob/main/doc/2026-Q4/concepts/decisions/state-001.md)
- [Guides](doc/guides/)

## Code-Beispiele

```dart
import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:aud_midi_state_matrix/aud_midi_state_matrix.dart';

void main() {
  // Eine Kette: Notenmatrix -> Controllermatrix -> Ausgang
  final controllers = MidiControllerMatrix(
    midiOut: (messages) => print('out: $messages'),
  );
  final notes = MidiNoteMatrix(midiOut: controllers.midiIn);

  const on50 = MidiNoteOn(channel: 9, note: 67, velocity: 50);
  const on60 = MidiNoteOn(channel: 9, note: 67, velocity: 60);
  const off = MidiNoteOff(channel: 9, note: 67);

  // Zwei NoteOns halten die Note, erst das letzte NoteOff lässt sie los.
  notes.midiIn([on50]); // out: das NoteOn
  notes.midiIn([on60]); // out: ein NoteOff, dann das neue NoteOn
  print(notes.slots(channel: 9, note: 67)); // [50, 60, 0, 0, 0]
  print(notes.activeNotes); // [MidiKey(channel: 9, note: 67)]
  notes.midiIn([off]); // nichts, die Note wird noch gehalten
  notes.midiIn([off]); // out: das NoteOff

  // Ohne Retrigger bleibt ein klingender Ton in Ruhe.
  notes.setRetriggerRepeatedNoteOns(channel: 9, value: false);
  notes.midiIn([on50, on60, off, off]); // out: das NoteOn, das NoteOff

  // Controller-Werte werden auf dem Weg gemerkt.
  notes.midiIn([
    const MidiControlChange(channel: 9, controller: 1, value: 100),
  ]);
  print(controllers.value(channel: 9, controller: 1)); // 100
  print(controllers.entries);
}
```

## Funktionsweise

Jede Zelle der `MidiNoteMatrix` ist ein Stapel von Velocity-Slots. Ein
NoteOn schreibt seine Velocity in den ersten freien Slot, ein NoteOff gibt
den zuletzt belegten Slot frei; die Zahl der belegten Slots sagt, wie
viele NoteOns die Note halten. Die Regeln in Richtung `midiOut`, `n` ist
die Zahl belegter Slots vor der Nachricht:

| Eingang | Zustand | Retrigger an | Retrigger aus |
| --- | --- | --- | --- |
| NoteOn | n = 0 | NoteOn senden | NoteOn senden |
| NoteOn | n ≥ 1 | NoteOff (Release 64), dann das neue NoteOn | nichts |
| NoteOff | n ≥ 2 | nichts | nichts |
| NoteOff | n = 1 | das NoteOff senden, wie empfangen | wie links |
| NoteOff | n = 0 | unverändert weiterreichen, kein Hänger | wie links |

Ein NoteOn mit Velocity 0 gilt als NoteOff. Alle anderen Nachrichten
laufen unverändert und in Reihenfolge durch. Eine Zelle zählt höchstens
`maxSlots` NoteOns (Standard 10): ein weiteres NoteOn wird nach den Regeln
oben gesendet, ersetzt aber nur die Velocity des zuletzt belegten Slots,
so dass ein Strom von NoteOns ohne NoteOffs die Matrix nicht wachsen
lässt.

Ein NoteOff, das nie ankommt, ließe eine Note endlos klingen. Drei Dinge
beenden solche Noten: All Sound Off, All Notes Off und die
Mode-Nachrichten, die es einschließen (CC 120, 123 bis 127), senden für
jede gehaltene Note ihres Kanals ein NoteOff, bevor sie durchlaufen;
`release`, `releaseChannel` und `releaseAll` tun dasselbe auf Zuruf, etwa
wenn ein Port verschwindet oder die App den Fokus verliert. Die
`MidiControllerMatrix` merkt sich jeden Control Change und reicht alle
Nachrichten weiter, so dass beide Matrizen verkettet werden können.

## Mitwirken

Siehe [doc/guides/develop-guide.md](doc/guides/develop-guide.md).
