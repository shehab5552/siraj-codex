import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'private account and encrypted marker are excluded from Android backup',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      for (final name in ['backup_rules', 'data_extraction_rules']) {
        final rules = File(
          'android/app/src/main/res/xml/$name.xml',
        ).readAsStringSync();
        for (final domain in [
          'root',
          'file',
          'database',
          'sharedpref',
          'external',
        ]) {
          expect(rules, contains('domain="$domain" path="."'));
        }
      }
    },
  );
}
