import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_marker_store.dart';
import 'package:siraj/features/auth/startup_session_resolver.dart';

class _MemoryMarkerStore implements SessionMarkerStore {
  String? value;
  bool failRead = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Simulated platform failure');
    return value;
  }

  @override
  Future<void> write(PersistedSessionMarker marker) async {
    value = marker.encode();
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  late AppDatabase db;
  late UserRepository users;
  late _MemoryMarkerStore markerStore;
  late StartupSessionResolver resolver;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    users = UserRepository(db);
    markerStore = _MemoryMarkerStore();
    resolver = StartupSessionResolver(users: users, markerStore: markerStore);
  });

  tearDown(() async => db.close());

  Future<void> createAccount() => users.create(
    userId: 'user-1',
    accountEpoch: 'epoch-1',
    usernameNormalized: 'student',
    usernameDisplay: 'Student',
    passwordSalt: Uint8List.fromList(List<int>.filled(16, 1)),
    passwordHash: Uint8List.fromList(List<int>.filled(32, 2)),
    passwordParamsJson: '{"test_only":true}',
    nowUtc: '2026-10-22T00:00:00Z',
  );

  PersistedSessionMarker marker([String nonce = 'valid-nonce']) =>
      PersistedSessionMarker(
        userId: 'user-1',
        accountEpoch: 'epoch-1',
        sessionNonce: nonce,
        issuedAt: '2026-10-22T00:00:00Z',
      );

  test(
    'no account never prompts Keystore and needs account creation',
    () async {
      markerStore.failRead = true;
      final decision = await resolver.resolve();
      expect(decision.status, StartupStatus.accountRequired);
      expect(decision.session, isNull);
    },
  );

  test('existing account with no marker requires login', () async {
    await createAccount();
    expect((await resolver.resolve()).status, StartupStatus.loginRequired);
  });

  test('valid Keystore marker and DB nonce restores session', () async {
    await createAccount();
    final digest = await Sha256().hash(utf8.encode('valid-nonce'));
    await users.setNonceHash(
      userId: 'user-1',
      accountEpoch: 'epoch-1',
      hash: Uint8List.fromList(digest.bytes),
      nowUtc: '2026-10-22T00:00:00Z',
    );
    await markerStore.write(marker());
    final decision = await resolver.resolve();
    expect(decision.status, StartupStatus.authenticated);
    expect(decision.session?.userId, 'user-1');
  });

  test('forged nonce always fails closed', () async {
    await createAccount();
    final digest = await Sha256().hash(utf8.encode('valid-nonce'));
    await users.setNonceHash(
      userId: 'user-1',
      accountEpoch: 'epoch-1',
      hash: Uint8List.fromList(digest.bytes),
      nowUtc: '2026-10-22T00:00:00Z',
    );
    await markerStore.write(marker('wrong-nonce'));
    expect((await resolver.resolve()).status, StartupStatus.loginRequired);
  });

  test('malformed marker does not log in', () async {
    await createAccount();
    markerStore.value = 'not-json';
    expect((await resolver.resolve()).status, StartupStatus.loginRequired);
  });

  test('Keystore read exception fails closed separately', () async {
    await createAccount();
    markerStore.failRead = true;
    expect(
      (await resolver.resolve()).status,
      StartupStatus.secureStorageUnavailable,
    );
  });
}
