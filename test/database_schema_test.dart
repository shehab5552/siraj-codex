import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';

const _created = '2026-10-21T00:00:00.000Z';

Future<void> _insertUser(AppDatabase db, String id, String epoch) async {
  await db.customInsert('''
    INSERT INTO user_profile
      (user_id, singleton_slot, account_epoch, username_normalized,
       username_display, password_kdf, password_salt, password_hash,
       password_params_json, created_at, updated_at)
    VALUES
      ('$id', 1, '$epoch', '$id', '$id', 'PBKDF2-HMAC-SHA256',
       X'01020304', X'05060708', '{}', '$_created', '$_created')
  ''');
}

Future<int> _count(AppDatabase db, String table) async {
  // This helper is only used with static table names in these tests.
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM $table')
      .getSingle();
  return row.read<int>('n');
}

void main() {
  group('in-memory schema verification', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('schema contains exactly the five P0 tables', () async {
      final rows = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      ''').get();
      expect(rows.map((r) => r.read<String>('name')).toList(), [
        'app_setting',
        'conversation',
        'installed_resource',
        'message',
        'user_profile',
      ]);
    });

    test('foreign keys are active and referenced rows are required', () async {
      final flag = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(flag.read<int>('foreign_keys'), 1);
      await expectLater(
        db.customInsert('''
          INSERT INTO conversation
            (conversation_id, user_id, created_at, updated_at)
          VALUES ('orphan', 'missing', '$_created', '$_created')
        '''),
        throwsA(isA<Exception>()),
      );
    });

    test('only one user can exist due to singleton_slot uniqueness', () async {
      await _insertUser(db, 'u1', 'epoch-1');
      await expectLater(
        _insertUser(db, 'u2', 'epoch-2'),
        throwsA(isA<Exception>()),
      );
      expect(await _count(db, 'user_profile'), 1);
    });

    test('invalid roles and resource kinds are rejected', () async {
      await _insertUser(db, 'u1', 'epoch-1');
      await db.customInsert('''
        INSERT INTO conversation (conversation_id,user_id,created_at,updated_at)
        VALUES ('c1','u1','$_created','$_created')
      ''');
      await expectLater(
        db.customInsert('''
          INSERT INTO message (message_id,conversation_id,role,content,created_at)
          VALUES ('m1','c1','SYSTEM','invalid','$_created')
        '''),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        db.customInsert('''
          INSERT INTO installed_resource(resource_id,kind,state,updated_at)
          VALUES ('r1','INVALID','READY','$_created')
        '''),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'deleting user cascades to owned records but preserves resources',
      () async {
        await _insertUser(db, 'u1', 'epoch-1');
        await db.customInsert('''
        INSERT INTO conversation (conversation_id,user_id,created_at,updated_at)
        VALUES ('c1','u1','$_created','$_created')
      ''');
        await db.customInsert('''
        INSERT INTO message (message_id,conversation_id,role,content,created_at)
        VALUES ('m1','c1','USER','question','$_created')
      ''');
        await db.customInsert('''
        INSERT INTO app_setting(user_id,setting_key,value_json,updated_at)
        VALUES ('u1','theme','"dark"','$_created')
      ''');
        await db.customInsert('''
        INSERT INTO installed_resource(resource_id,kind,state,updated_at)
        VALUES ('book-1','PDF','READY','$_created')
      ''');

        await db.customUpdate("DELETE FROM user_profile WHERE user_id='u1'");
        expect(await _count(db, 'user_profile'), 0);
        expect(await _count(db, 'conversation'), 0);
        expect(await _count(db, 'message'), 0);
        expect(await _count(db, 'app_setting'), 0);
        expect(await _count(db, 'installed_resource'), 1);
      },
    );

    test(
      'transaction rollback keeps previously committed data unchanged',
      () async {
        await _insertUser(db, 'u1', 'epoch-1');
        try {
          await db.transaction(() async {
            await db.customInsert('''
            INSERT INTO conversation
              (conversation_id,user_id,created_at,updated_at)
            VALUES ('rollback-c1','u1','$_created','$_created')
          ''');
            throw StateError('forced failure');
          });
        } on StateError {
          // Expected failure: verifies the transaction was rolled back.
        }
        expect(await _count(db, 'user_profile'), 1);
        expect(await _count(db, 'conversation'), 0);
      },
    );

    test('both chronological indexes exist', () async {
      final rows = await db.customSelect('''
        SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'ix_%'
        ORDER BY name
      ''').get();
      expect(rows.map((r) => r.read<String>('name')).toList(), [
        'ix_conversation_owner_created',
        'ix_message_conversation_created',
      ]);
    });

    test('unsupported password KDF is rejected', () async {
      await expectLater(
        db.customInsert('''
          INSERT INTO user_profile
            (user_id, singleton_slot, account_epoch, username_normalized,
             username_display, password_kdf, password_salt, password_hash,
             password_params_json, created_at, updated_at)
          VALUES
            ('bad-kdf', 1, 'epoch-bad', 'bad-kdf', 'bad-kdf',
             'PLAIN_TEXT', X'01020304', X'05060708', '{}',
             '$_created', '$_created')
        '''),
        throwsA(isA<Exception>()),
      );
      expect(await _count(db, 'user_profile'), 0);
    });
  });

  test('v1 database can reopen without losing records', () async {
    final folder = await Directory.systemTemp.createTemp('siraj-b03-');
    final path = File(
      '${folder.path}${Platform.pathSeparator}siraj_test.sqlite',
    );
    try {
      final first = AppDatabase.forTesting(NativeDatabase(path));
      await _insertUser(first, 'u1', 'epoch-1');
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(path));
      expect(await _count(second, 'user_profile'), 1);
      await second.close();
    } finally {
      await folder.delete(recursive: true);
    }
  });
}
