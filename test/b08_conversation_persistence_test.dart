import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';

void main() {
  late AppDatabase db;
  late ConversationRepository chats;
  late UserRepository users;
  final nonce = Uint8List.fromList(List<int>.filled(32, 7));
  const now = '2026-11-06T00:00:00Z';
  Future<void> first() => chats.saveFirstUserMessage(
    userId: 'u',
    accountEpoch: 'e',
    conversationId: 'c',
    messageId: 'u1',
    question: 'first',
    nowUtc: now,
    expectedNonceHash: nonce,
  );
  Future<void> follow([String question = 'next']) => chats.saveUserFollowUp(
    userId: 'u',
    accountEpoch: 'e',
    expectedNonceHash: nonce,
    conversationId: 'c',
    messageId: 'u2',
    question: question,
    nowUtc: now,
  );
  Future<void> assistant() => chats.appendAssistantMessage(
    userId: 'u',
    accountEpoch: 'e',
    conversationId: 'c',
    messageId: 'a1',
    answer: 'test-only verified result',
    sourceRefsJson: '[]',
    nowUtc: now,
    expectedNonceHash: nonce,
  );
  Future<int> count() async => (await chats.listMessages(
    userId: 'u',
    accountEpoch: 'e',
    conversationId: 'c',
  )).length;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    chats = ConversationRepository(db);
    users = UserRepository(db);
    await users.create(
      userId: 'u',
      accountEpoch: 'e',
      usernameNormalized: 'student',
      usernameDisplay: 'Student',
      passwordSalt: Uint8List.fromList([1]),
      passwordHash: Uint8List.fromList([2]),
      passwordParamsJson: '{}',
      nowUtc: now,
    );
    await users.setNonceHash(
      userId: 'u',
      accountEpoch: 'e',
      hash: nonce,
      nowUtc: now,
    );
  });
  tearDown(() => db.close());
  test(
    'follow-up same conversation idempotent and payload conflict rejected',
    () async {
      await first();
      await follow();
      await follow();
      expect(await count(), 2);
      await expectLater(follow('changed'), throwsStateError);
      expect(await count(), 2);
    },
  );
  test('assistant retry is idempotent', () async {
    await first();
    await assistant();
    await assistant();
    expect(await count(), 2);
  });
  test('logout between precheck and first commit blocks transaction', () async {
    await users.invalidateNonce(userId: 'u', accountEpoch: 'e', nowUtc: now);
    await expectLater(first(), throwsStateError);
    expect(await count(), 0);
  });
  test('logout prevents follow-up and assistant writes', () async {
    await first();
    await users.invalidateNonce(userId: 'u', accountEpoch: 'e', nowUtc: now);
    await expectLater(follow(), throwsStateError);
    await expectLater(assistant(), throwsStateError);
    expect(await count(), 1);
  });
  test('delete prevents resurrection by a late answer or follow-up', () async {
    await first();
    await chats.deleteConversation(
      userId: 'u',
      accountEpoch: 'e',
      conversationId: 'c',
    );
    await expectLater(follow(), throwsStateError);
    await expectLater(assistant(), throwsStateError);
    expect(await count(), 0);
  });
}
