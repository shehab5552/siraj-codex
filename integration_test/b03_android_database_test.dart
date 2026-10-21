import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/data/app_database.dart';

/// A temporary, isolated SQLite file on the Android device.
/// NEVER uses the production `siraj_p0` database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B-03: Android SQLite file, schema v1, FK, CRUD, cascade', (
    tester,
  ) async {
    final temp = await Directory.systemTemp.createTemp('siraj_b03_device_');
    final file = File('${temp.path}${Platform.pathSeparator}b03_smoke.sqlite');
    AppDatabase? database;
    try {
      database = AppDatabase.forTesting(NativeDatabase(file));

      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);

      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 1);

      const utc = '2026-10-21T00:00:00.000Z';
      await database.customInsert(
        '''
        INSERT INTO user_profile
          (user_id, account_epoch, username_normalized, username_display,
           password_kdf, password_salt, password_hash, password_params_json,
           created_at, updated_at)
        VALUES (?, ?, ?, ?, 'PBKDF2-HMAC-SHA256', X'0102', X'0304', '{}', ?, ?)
      ''',
        variables: [
          Variable.withString('device-test-user'),
          Variable.withString('device-test-epoch'),
          Variable.withString('device-test-user'),
          Variable.withString('Device Test'),
          Variable.withString(utc),
          Variable.withString(utc),
        ],
      );
      await database.customInsert(
        '''
        INSERT INTO conversation
          (conversation_id, user_id, created_at, updated_at)
        VALUES ('device-c1', 'device-test-user', ?, ?)
      ''',
        variables: [Variable.withString(utc), Variable.withString(utc)],
      );
      await database.customInsert(
        '''
        INSERT INTO message
          (message_id, conversation_id, role, content, created_at)
        VALUES ('device-m1', 'device-c1', 'USER', 'Biology test', ?)
      ''',
        variables: [Variable.withString(utc)],
      );
      await database.customInsert(
        '''
        INSERT INTO installed_resource
          (resource_id, kind, state, updated_at)
        VALUES ('device-book', 'PDF', 'MISSING', ?)
      ''',
        variables: [Variable.withString(utc)],
      );

      final saved = await database.customSelect('''
        SELECT m.content FROM message m
        JOIN conversation c ON c.conversation_id = m.conversation_id
        WHERE c.user_id = 'device-test-user'
      ''').getSingle();
      expect(saved.read<String>('content'), 'Biology test');

      await database.customUpdate(
        "DELETE FROM user_profile WHERE user_id = 'device-test-user'",
      );
      final messages = await database
          .customSelect('SELECT COUNT(*) AS n FROM message')
          .getSingle();
      expect(messages.read<int>('n'), 0);
      final resources = await database
          .customSelect('SELECT COUNT(*) AS n FROM installed_resource')
          .getSingle();
      expect(
        resources.read<int>('n'),
        1,
        reason: 'Device resources must survive account deletion',
      );
    } finally {
      await database?.close();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });
}
