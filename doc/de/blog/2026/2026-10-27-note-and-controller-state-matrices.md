# Noten- und Controller-Zustandsmatrizen

## Motivation

- Eine Instrument-App, die mehrere Eingänge auf einen MIDI-Ausgang
  zusammenführt, muss wissen, welche Noten gerade klingen, wie oft jede
  gehalten wird und welche Controller-Werte aktuell sind.
- Ohne diesen Zustand beendet das erste Note Off eine Note, die zwei
  Eingänge spielen, wiederholte Note Ons stapeln sich am Ausgang, und ein
  Note Off, das nie ankommt, lässt eine Note endlos hängen.
- Dieses Paket hält den Zustand in zwei Matrizen und stellt sie als Kette
  vor einen Ausgang.

## Strategie

- `MidiNoteMatrix`: 16 Kanäle × 128 Noten, jede Zelle ein Stapel von
  Velocity-Slots, einer pro Note On, das die Note hält.
- `MidiControllerMatrix`: 16 Kanäle × 128 Controller mit dem jeweils
  letzten Wert.
- Beide nehmen Nachrichten über `midiIn` entgegen und reichen das Ergebnis
  an einen `MidiMessageCallback` weiter, so stehen sie an beliebiger
  Stelle zwischen Eingängen und Ausgängen.
- Reines Dart ohne I/O; einzige Abhängigkeit ist `aud_midi_standard`.
- Jede Regel des Entwurfs ist ein Test; die Abdeckung liegt pro Datei bei
  100 %.

## Realisierung 1: die Notenmatrix

- Ein Note On schreibt seine Velocity in den ersten freien Slot seiner
  Zelle, ein Note Off gibt den zuletzt belegten Slot frei; die Zahl der
  belegten Slots sagt, wie viele Note Ons die Note halten.
- Zum Ausgang gelangen nur das erste Note On und das letzte Note Off. Ein
  wiederholtes Note On sendet ein Note Off und das neue Note On, solange
  `retriggerRepeatedNoteOns` für den Kanal wahr ist, und sonst nichts. Ein
  Note On mit Velocity 0 gilt als Note Off, ein Note Off einer stillen
  Note läuft durch, jede andere Nachricht läuft unverändert und in
  Reihenfolge durch.
- `activeNotes` listet die Zellen, die eine Note halten, als `MidiKey` in
  der Reihenfolge, in der sie aktiv wurden; `velocities`, `slots`,
  `count` und `isActive` lesen eine Zelle.
- Zellen beginnen mit fünf Slots und verdoppeln sie bei Bedarf, bis zu
  `maxSlots` (Standard 10). Eine volle Zelle zählt kein weiteres Note On;
  die neueste Velocity ersetzt den zuletzt belegten Slot, so dass ein
  Strom von Note Ons ohne Note Offs die Matrix nicht wachsen lässt.

## Realisierung 2: Noten beenden, deren Note Off nie kommt

- `release(channel:, note:)`, `releaseChannel(channel)` und
  `releaseAll()` senden für jede gehaltene Note in ihrem Bereich ein Note
  Off und geben die Zellen frei; `reset()` leert still.
- All Sound Off, All Notes Off und die Mode-Nachrichten, die All Notes Off
  einschließen (CC 120, 123 bis 127), lassen die gehaltenen Noten ihres
  Kanals los und laufen nach den Note Offs durch. CC 121 und 122 lassen
  die Noten in Ruhe.

## Realisierung 3: die Controller-Matrix

- `midiIn` merkt sich jeden Control Change und reicht alle Nachrichten
  unverändert weiter, in einem Aufruf pro Stapel, als Kopie der Liste.
- `value` liefert den letzten Wert oder null, `isSet`, ob einer bekannt
  ist, `set` merkt sich einen Wert ohne zu senden, `reset` und
  `resetChannel` vergessen.
- `entries` listet die bekannten Werte als `MidiControlChange`-Nachrichten
  in der Reihenfolge, in der ihre Zellen zuerst gesetzt wurden, bereit zum
  Senden, um einen Zustand wiederherzustellen.

## Realisierung 4: Beispiel und Dokumentation

- Das Beispiel verkettet Notenmatrix, Controller-Matrix und einen
  druckenden Ausgang und spielt das Szenario aus zwei Note Ons und zwei
  Note Offs mit und ohne Retrigger durch.
- Die READMEs in Englisch und Deutsch erklären die Senderegeln als Tabelle
  und die Wege, hängende Noten zu beenden; die `index.jsonc` nennt beide
  Matrizen und die aus `aud_midi_standard` genutzten Typen.

## Aktualisierte Abhängigkeiten

- `aud_midi_standard` 0.2.0 liefert `MidiKey` für die Aktiv-Liste und
  `MidiMessageCallback` für `midiOut`; die Einträge der Controller-Matrix
  sind dessen `MidiControlChange`.
- Die DNA-Schicht `dna_audanika` 0.1.0 bringt die Blog- und
  Übersetzungs-Guides, denen dieser Post folgt, einen Prompt-Hook und ein
  README-Prüfskript.

## Offene Punkte

- Die Quelle jeder gehaltenen Note merken, damit ein verschwundener Port
  oder eine beendete Touch-Sitzung nur die eigenen Noten loslässt
  (`releaseSource`).
- Ein optionales Zeitlimit, das die App treibt (`sweep(now)`, `maxHold`
  pro Kanal).
- Reset All Controllers (CC 121) in der Controller-Matrix,
  14-Bit-Controller-Paare, RPN/NRPN und MIDI-2.0-Nachrichten.
