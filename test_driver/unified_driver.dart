import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Official host driver. Keeping the isolated app installed is required for
/// process-death/Keystore/SQLite evidence; no app data is restored or fabricated.
Future<void> main() async {
  await integrationDriver(
    responseDataCallback: (data) async {
      final result = data?['siraj_test_results'];
      if (result is! Map ||
          result['target'] is! String ||
          !RegExp(r'^[a-z-]{1,40}$').hasMatch(result['target'] as String)) {
        throw StateError('Native result counts are missing');
      }
      final dir = Directory('dist/native-results');
      await dir.create(recursive: true);
      await File(
        '${dir.path}/${result['target']}.json',
      ).writeAsString(jsonEncode(result));
      stdout.writeln('SIRAJ_NATIVE_RESULTS ${jsonEncode(result)}');
    },
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(name) ||
          bytes.length > 20 * 1024 * 1024) {
        return false;
      }
      final dir = Directory('dist/screenshots');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png').writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
