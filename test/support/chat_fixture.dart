import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_guard.dart';

/// No KDF shortcut is wired into the app. Disposable tests seed their own DB.
class ChatFixture {
  ChatFixture({AppDatabase? database})
    : db = database ?? AppDatabase.forTesting(NativeDatabase.memory());
  final AppDatabase db;
  late final users = UserRepository(db);
  late final conversations = ConversationRepository(db);
  late final guard = SessionGuard(users);
  final session = const AuthSession(
    userId: 'chat-user',
    accountEpoch: 'chat-epoch',
    sessionNonce: 'test-only-nonce',
  );
  late Uint8List nonceHash;
  static const stamp = '2026-10-22T12:00:00.000Z';

  Future<void> initialize() async {
    await users.create(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      usernameNormalized: 'chat-test',
      usernameDisplay: 'Chat Test',
      passwordSalt: Uint8List.fromList([1]),
      passwordHash: Uint8List.fromList([2]),
      passwordParamsJson: '{}',
      nowUtc: stamp,
    );
    nonceHash = Uint8List.fromList(
      (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
    );
    await users.setNonceHash(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      hash: nonceHash,
      nowUtc: stamp,
    );
  }

  Future<void> logout() => users.invalidateNonce(
    userId: session.userId,
    accountEpoch: session.accountEpoch,
    nowUtc: stamp,
  );
  Future<void> close() => db.close();
}
