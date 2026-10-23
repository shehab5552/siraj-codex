import 'package:flutter/widgets.dart';
import 'app/siraj_app.dart';

/// Isolated debug-only V2 showcase; production entrypoint is lib/main.dart.
/// AppBootstrap gates this override with kDebugMode and makes no session.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SirajApp(debugPreview: true));
}
