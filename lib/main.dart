import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/siraj_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans Arabic',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const SirajApp());
}
