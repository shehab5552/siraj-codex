import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/resource_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/session_marker_store.dart';

class _FakeMarkerStore implements SessionMarkerStore {
  String? raw;
  bool failWrite = false;
  bool failRead = false;
  bool failClear = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('storage not available');
    return raw;
  }

  @override
  Future<void> write(PersistedSessionMarker marker) async {
    if (failWrite) throw StateError('storage failed');
    raw = marker.encode();
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('storage failed');
    raw = null;
  }
}

const _username = 'طالب';
const _password = 'اختبار_قوي_بدون_بيانات_حقيقية';
const _now = '2026-10-21T00:00:00.000Z';

void main() {
  group('B-04 AuthService - test-only PBKDF2 (1000 iterations)', () {
    late AppDatabase db;
    late UserRepository users;
    late _FakeMarkerStore markers;
    late AuthService service;

    AuthService makeService() => AuthService(
      users: users,
      passwordHasher: PasswordHasher(iterations: 1000),
      markerStore: markers,
      now: () => DateTime.utc(2026, 10, 21),
    );

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      users = UserRepository(db);
      markers = _FakeMarkerStore();
      service = makeService();
    });
    tearDown(() async => db.close());

    Future<AuthSession> create() => service.createAccount(
      username: _username,
      password: _password,
      confirmation: _password,
    );

    Future<void> expectFailure(
      Future<Object?> Function() operation,
      AuthFailureCode code,
    ) async {
      await expectLater(
        operation(),
        throwsA(isA<AuthFailure>().having((e) => e.code, 'code', code)),
      );
    }

    test('signup hashes password, stores only nonce hash in SQLite', () async {
      final session = await create();
      final row = (await users.currentAccount())!;
      expect(row.read<String>('username_normalized'), _username);
      expect(row.read<String>('password_kdf'), PasswordHasher.algorithm);
      expect(row.read<String>('password_params_json'), contains('1000'));
      expect(row.read<Uint8List>('password_hash').length, 32);
      expect(row.read<Uint8List>('password_salt').length, 16);
      expect(row.read<Uint8List>('active_session_nonce_hash').length, 32);
      expect(session.sessionNonce, isNotEmpty);
      expect(markers.raw, contains(session.sessionNonce)); // Fake only.
      expect(
        row.read<String>('password_params_json'),
        isNot(contains(_password)),
      );
      expect(await service.checkSession(session), isTrue);
    });

    test(
      'incorrect confirmation rejects signup without writing account',
      () async {
        await expectFailure(
          () => service.createAccount(
            username: _username,
            password: _password,
            confirmation: 'different',
          ),
          AuthFailureCode.invalidInput,
        );
        expect(await users.currentAccount(), isNull);
      },
    );

    test('database singleton cannot be bypassed by repeated signup', () async {
      await create();
      await expectFailure(() => create(), AuthFailureCode.accountAlreadyExists);
      expect(await users.currentAccount(), isNotNull);
    });

    test('login verifies password and username normalization', () async {
      final first = await create();
      await service.logout();
      await expectFailure(
        () => service.login(username: _username, password: 'wrong'),
        AuthFailureCode.invalidCredentials,
      );
      final second = await service.login(
        username: '  $_username  ',
        password: _password,
      );
      expect(second.userId, first.userId);
      expect(second.sessionNonce, isNot(first.sessionNonce));
      expect(await service.checkSession(second), isTrue);
    });

    test(
      'restore validates secure marker against DB nonce hash and epoch',
      () async {
        final original = await create();
        final restartedService = makeService();
        final restored = await restartedService.restoreSession();
        expect(restored?.userId, original.userId);
        expect(await restartedService.checkSession(restored!), isTrue);
        final altered = PersistedSessionMarker(
          userId: original.userId,
          accountEpoch: original.accountEpoch,
          sessionNonce: 'tampered',
          issuedAt: _now,
        );
        markers.raw = altered.encode();
        expect(await makeService().restoreSession(), isNull);
        expect(markers.raw, isNull);
      },
    );

    test(
      'malformed marker fails closed and never creates new account',
      () async {
        await create();
        markers.raw = '{not json';
        expect(await makeService().restoreSession(), isNull);
        expect(await users.currentAccount(), isNotNull);
      },
    );

    test(
      'logout invalidates DB before clearing marker; stale marker cannot restore',
      () async {
        final session = await create();
        final oldRaw = markers.raw;
        markers.failClear = true;
        await service.logout();
        expect(service.activeSession, isNull);
        expect(await service.checkSession(session), isFalse);
        markers.raw = oldRaw;
        markers.failClear = false;
        expect(await makeService().restoreSession(), isNull);
      },
    );

    test(
      'delete requires confirmation; cascades owned rows and preserves resource',
      () async {
        final session = await create();
        await db.customInsert(
          '''
        INSERT INTO installed_resource
          (resource_id,kind,state,updated_at)
        VALUES ('test-pdf','PDF','MISSING',?)
      ''',
          variables: [
            // Don't turn this into a test of ResourceManager readiness.
            Variable.withString(_now),
          ],
        );
        final chats = ConversationRepository(db);
        await chats.saveFirstUserMessage(
          userId: session.userId,
          accountEpoch: session.accountEpoch,
          conversationId: 'c1',
          messageId: 'm1',
          question: 'ما هي الخلية؟',
          nowUtc: _now,
        );
        await expectFailure(
          () => service.deleteCurrentAccount(confirmed: false),
          AuthFailureCode.confirmationRequired,
        );
        expect(await users.currentAccount(), isNotNull);
        await service.deleteCurrentAccount(confirmed: true);
        expect(await users.currentAccount(), isNull);
        expect(
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM conversation')
                  .getSingle())
              .read<int>('n'),
          0,
        );
        expect(
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM message')
                  .getSingle())
              .read<int>('n'),
          0,
        );
        expect(
          (await ResourceRepository(
            db,
          ).find(kind: 'PDF', resourceId: 'test-pdf'))?.read<String>('state'),
          'MISSING',
        );
        expect(await service.checkSession(session), isFalse);
      },
    );

    test(
      'new account after delete uses fresh epoch; old marker cannot hijack',
      () async {
        final oldSession = await create();
        final oldMarker = markers.raw;
        await service.deleteCurrentAccount(confirmed: true);
        final fresh = await create();
        expect(fresh.accountEpoch, isNot(oldSession.accountEpoch));
        markers.raw = oldMarker;
        expect(await makeService().restoreSession(), isNull);
        expect(await service.checkSession(oldSession), isFalse);
      },
    );

    test('secure marker write failure does not grant a session', () async {
      markers.failWrite = true;
      await expectFailure(() => create(), AuthFailureCode.secureStorageFailure);
      expect(service.activeSession, isNull);
      final row = (await users.currentAccount())!;
      expect(row.read<Uint8List?>('active_session_nonce_hash'), isNull);
      expect(await makeService().restoreSession(), isNull);
    });

    test('keystore read failure must not auto-login', () async {
      await create();
      markers.failRead = true;
      await expectFailure(
        () => makeService().restoreSession(),
        AuthFailureCode.secureStorageFailure,
      );
    });
  });
}
