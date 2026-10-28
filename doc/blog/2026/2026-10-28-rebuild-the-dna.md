<!--
@license
Copyright (c) audanika

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Rebuild the DNA

## Motivation

- The packages of this family are maintained in one pass: every repo moves to
  the current SDK, takes the current versions of its dependencies and rebuilds
  its DNA instances.
- The SDK floor of this repo was current already; its share of the pass is the
  dependencies and the DNA.

## Strategy

- Let `gg do upgrade deps` lift every dependency to its current version and
  tighten the constraints to what resolved.
- Rebuild the DNA with `gg dna build` and let the DNA test of the repo verify
  the instances when the checks run.
- Keep the public API untouched.

## Implementation 1: SDK and dependencies

- `pubspec.yaml`: the SDK constraint stays, it was `>=3.13.0` already.
- The analyzer and the tests stay green.

## Implementation 2: DNA instances

- `dna/_vars.json` already carried everything the layers ask for and stays as
  it is.
- `gg dna build` instantiated the layers: the blog guide and its templates, the
  translate guide, the refreshed README guides with `scripts/check-readme.js`,
  the updated AI guides and the `/blog`, `/translate` and `/readme` skills.
- The instances landed as the commit `#gg: generated DNA`.

## Open Points

- The README does not follow the new README template yet:
  `scripts/check-readme.js` reports the missing sections and the missing
  language switcher. A follow-up pass brings it in line.
- The translate guide asks for a German copy of every file under `doc`; this
  post has one, the rest follows with the README pass.
