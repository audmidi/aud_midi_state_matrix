<!--
@license
Copyright (c) audanika

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Die DNA neu bauen

## Motivation

- Die Pakete dieser Familie werden in einem Durchgang gepflegt: Jedes Repo
  wechselt auf das aktuelle SDK, übernimmt die aktuellen Versionen seiner
  Abhängigkeiten und baut seine DNA-Instanzen neu.
- Die SDK-Untergrenze dieses Repos war bereits aktuell; sein Anteil am
  Durchgang sind die Abhängigkeiten und die DNA.

## Strategie

- `gg do upgrade deps` jede Abhängigkeit auf ihre aktuelle Version heben und
  die Bedingungen auf das Aufgelöste festziehen lassen.
- Die DNA mit `gg dna build` neu bauen und den DNA-Test des Repos die Instanzen
  prüfen lassen, wenn die Checks laufen.
- Die öffentliche API unangetastet lassen.

## Realisierung 1: SDK und Abhängigkeiten

- `pubspec.yaml`: Die SDK-Bedingung bleibt, sie war bereits `>=3.13.0`.
- Analyzer und Tests bleiben grün.

## Realisierung 2: DNA-Instanzen

- `dna/_vars.json` trug bereits alles, was die Schichten verlangen, und bleibt
  wie es ist.
- `gg dna build` hat die Schichten instanziiert: den Blog-Guide mit seinen
  Vorlagen, den Translate-Guide, die überarbeiteten README-Guides mit
  `scripts/check-readme.js`, die aktualisierten KI-Guides und die Skills
  `/blog`, `/translate` und `/readme`.
- Die Instanzen landeten als Commit `#gg: generated DNA`.

## Offene Punkte

- Die README folgt der neuen README-Vorlage noch nicht:
  `scripts/check-readme.js` meldet die fehlenden Abschnitte und den fehlenden
  Sprachumschalter. Ein Folgedurchgang bringt sie in Form.
- Der Translate-Guide verlangt eine deutsche Kopie jeder Datei unter `doc`;
  dieser Post hat eine, der Rest folgt mit dem README-Durchgang.
