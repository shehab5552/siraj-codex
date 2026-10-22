import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';

import 'support/chat_fixture.dart';

class LogoutAfterGuard extends SessionGuard {
  LogoutAfterGuard(super.users, this.afterCheck);
  final Future<void> Function() afterCheck;
  @override
  Future<bool> isCurrent(AuthSession session) async {
    final valid = await super.isCurrent(session);
    await afterCheck();
    return valid;
  }
}

void main() {
  late ChatFixture f;
  setUp(() async {
    f = ChatFixture();
    await f.initialize();
  });
  tearDown(() => f.close());

  Future<void> first() => f.conversations.saveFirstUserMessage(
    userId: f.session.userId,
    accountEpoch: f.session.accountEpoch,
    conversationId: 'c',
    messageId: 'm1',
    question: 'first',
    nowUtc: ChatFixture.stamp,
    sessionNonceHash: f.nonceHash,
  );
  Future<void> follow(String id, {String question = 'follow'}) =>
      f.conversations.appendUserMessage(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: 'c',
        messageId: id,
        question: question,
        nowUtc: ChatFixture.stamp,
        sessionNonceHash: f.nonceHash,
      );
  Future<void> assistant() => f.conversations.appendAssistantMessage(
    userId: f.session.userId,
    accountEpoch: f.session.accountEpoch,
    conversationId: 'c',
    messageId: 'm1-assistant',
    answer: 'answer',
    sourceRefsJson: '[]',
    nowUtc: ChatFixture.stamp,
    sessionNonceHash: f.nonceHash,
  );
  Future<int> count() async => (await f.conversations.listMessages(
    userId: f.session.userId,
    accountEpoch: f.session.accountEpoch,
    conversationId: 'c',
  )).length;

  test(
    'logout between SessionGuard and first transaction prevents all writes',
    () async {
      final draft = ConversationDraftController(
        conversations: f.conversations,
        guard: LogoutAfterGuard(UserRepository(f.db), f.logout),
      );
      await expectLater(
        draft.commitFirstQuestion(session: f.session, question: 'question'),
        throwsA(anything),
      );
      expect(
        await f.conversations.listConversations(
          userId: f.session.userId,
          accountEpoch: f.session.accountEpoch,
        ),
        isEmpty,
      );
    },
  );
  test('follow-up is owned, nonce guarded, and idempotent', () async {
    await first();
    await follow('m2');
    await follow('m2');
    expect(await count(), 2);
    await expectLater(
      follow('m2', question: 'different'),
      throwsA(isA<ChatPersistenceFailure>()),
    );
    expect(await count(), 2);
  });
  test('assistant retry with same id does not duplicate', () async {
    await first();
    await assistant();
    await assistant();
    expect(await count(), 2);
  });
  test(
    'first commit reports actual eviction, idempotent retry does not',
    () async {
      Future<FirstUserMessageCommit> save(int i) =>
          f.conversations.saveFirstUserMessageWithOutcome(
            userId: f.session.userId,
            accountEpoch: f.session.accountEpoch,
            conversationId: 'chat-$i',
            messageId: 'user-$i',
            question: 'question $i',
            nowUtc: ChatFixture.stamp,
            sessionNonceHash: f.nonceHash,
          );
      for (var i = 0; i < 10; i++) {
        expect((await save(i)).evictedOldest, false);
      }
      final committed = await save(10);
      expect(committed.conversationId, 'chat-10');
      expect(committed.evictedOldest, true);
      expect((await save(10)).evictedOldest, false);
      expect(
        await f.conversations.listConversations(
          userId: f.session.userId,
          accountEpoch: f.session.accountEpoch,
        ),
        hasLength(10),
      );
    },
  );
  test('all late chat writes reject revoked nonce', () async {
    await first();
    await f.logout();
    await expectLater(follow('m2'), throwsA(isA<ChatPersistenceFailure>()));
    await expectLater(assistant(), throwsA(isA<ChatPersistenceFailure>()));
    expect(await count(), 1);
  });
  test(
    'nonce rotation blocks old session even under the same account epoch',
    () async {
      await first();
      await f.users.setNonceHash(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        hash: Uint8List.fromList(List.filled(32, 8)),
        nowUtc: ChatFixture.stamp,
      );
      await expectLater(assistant(), throwsA(isA<ChatPersistenceFailure>()));
      expect(await count(), 1);
    },
  );
  test('invalid session cannot read history through guarded queries', () async {
    await first();
    await f.logout();
    expect(
      await f.conversations.listConversations(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        sessionNonceHash: f.nonceHash,
      ),
      isEmpty,
    );
    await expectLater(
      f.conversations.listMessages(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: 'c',
        sessionNonceHash: f.nonceHash,
      ),
      throwsA(isA<ChatPersistenceFailure>()),
    );
  });
  test('cancelled persistence never inserts a follow-up', () async {
    await first();
    await expectLater(
      f.conversations.appendUserMessage(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: 'c',
        messageId: 'cancelled',
        question: 'q',
        nowUtc: ChatFixture.stamp,
        sessionNonceHash: f.nonceHash,
        isRequestCurrent: () => false,
      ),
      throwsA(isA<ChatPersistenceFailure>()),
    );
    expect(await count(), 1);
  });
  test(
    'session watch observes invalidation from existing Auth repository',
    () async {
      final events = f.conversations
          .watchSession(
            userId: f.session.userId,
            accountEpoch: f.session.accountEpoch,
            sessionNonceHash: f.nonceHash,
          )
          .asBroadcastStream();
      expect(await events.first, true);
      final expired = events.firstWhere((current) => !current);
      await f.logout();
      expect(await expired.timeout(const Duration(seconds: 2)), false);
    },
  );
  test('database failure rolls back assistant and retains USER', () async {
    await first();
    await f.db.customStatement(
      "CREATE TRIGGER fail_assistant BEFORE INSERT ON message WHEN NEW.role = 'ASSISTANT' BEGIN SELECT RAISE(ABORT, 'isolated failure'); END;",
    );
    await expectLater(assistant(), throwsA(anything));
    expect(await count(), 1);
  });
}
