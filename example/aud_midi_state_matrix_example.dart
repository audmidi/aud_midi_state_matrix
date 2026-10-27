#!/usr/bin/env dart

// @license
// Copyright (c) audmidi
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:aud_midi_state_matrix/aud_midi_state_matrix.dart';

Future<void> main() async {
  print(const AudMidiStateMatrix().greet('World'));
}
