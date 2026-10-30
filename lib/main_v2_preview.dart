import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/siraj_app.dart';
import 'core/design/siraj_design.dart';
import 'features/home/siraj_main_shell.dart';

/// Explicit, isolated layout preview. No test fake is granted session access.
/// Never bypass production authentication if someone builds this target in release.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const SirajApp());
    return;
  }
  runApp(MaterialApp(
    title: 'سراج — معاينة V2',
    debugShowCheckedModeBanner: false,
    theme: SirajTheme.light(),
    darkTheme: SirajTheme.dark(),
    themeMode: ThemeMode.system,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const SirajMainShell(),
  ));
}
