import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'ZXing core 3.5.4 — ZXing authors',
      'ZXing Android Embedded 4.3.0 — Journey Mobile and ZXing authors',
    ], await rootBundle.loadString('assets/licenses/zxing-Apache-2.0.txt'));
    yield LicenseEntryWithLineBreaks([
      'Phosphor Icons',
    ], await rootBundle.loadString('assets/licenses/phosphor-MIT.txt'));
    for (final family in ['manrope', 'notosansarmenian']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
  runApp(const ProviderScope(child: ShannonApp()));
}
