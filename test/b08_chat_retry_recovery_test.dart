import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';

import 'support/chat_fixture.dart';
import 'support/fake_tutor.dart';

class LostAssistantAcknowledgment extends ConversationRepository {
  LostAssistantAcknowledgment(super.db);
  bool failOnce = true;
  @override
  Future<void> appendAssistantMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String answer,
    required String sourceRefsJson,
    required String nowUtc,
    Uint8List? sessionNonceHash,
    bool Function()? isRequestCurrent,
    String? inReplyToMessageId,
  }) async {
    await super.appendAssistantMessage(
      userId: userId,
      accountEpoch: accountEpoch,
      conversationId: conversationId,
      messageId: messageId,
      answer: answer,
      sourceRefsJson: sourceRefsJson,
      nowUtc: nowUtc,
      sessionNonceHash: sessionNonceHash,
      isRequestCurrent: isRequestCurrent,
      inReplyToMessageId: inReplyToMessageId,
    );
    if (failOnce) {
      failOnce = false;
      throw StateError('isolated lost acknowledgement after COMMIT');
    }
  }
}

class PausedAcknowledgment extends ConversationRepository {
  PausedAcknowledgment(super.db);
  final committed = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> appendAssistantMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String answer,
    required String sourceRefsJson,
    required String nowUtc,
    Uint8List? sessionNonceHash,
    bool Function()? isRequestCurrent,
    String? inReplyToMessageId,
  }) async {
    await super.appendAssistantMessage(
      userId: userId,
      accountEpoch: accountEpoch,
      conversationId: conversationId,
      messageId: messageId,
      answer: answer,
      sourceRefsJson: sourceRefsJson,
      nowUtc: nowUtc,
      sessionNonceHash: sessionNonceHash,
      isRequestCurrent: isRequestCurrent,
      inReplyToMessageId: inReplyToMessageId,
    );
    committed.complete();
    await release.future;
  }
}

void main() {
  late ChatFixture f;
  late FakeTutor tutor;
  late ChatTurnCoordinator c;
  setUp(() async {
    f = ChatFixture();
    await f.initialize();
    tutor = FakeTutor();
  });
  tearDown(() async {
    c.dispose();
    await f.close();
  });
  Future<List<String>> roles() async => (await f.conversations.listMessages(
    userId: f.session.userId,
    accountEpoch: f.session.accountEpoch,
    conversationId: c.conversationId!,
  )).map((row) => row.read<String>('role')).toList();

  test('first USER transaction failure retains a retryable draft', () async {
    c = ChatTurnCoordinator(
      session: f.session,
      conversations: f.conversations,
      guard: f.guard,
      tutor: tutor,
    );
    await c.initialize();
    await f.db.customStatement(
      "CREATE TRIGGER fail_user BEFORE INSERT ON message WHEN NEW.role='USER' BEGIN SELECT RAISE(ABORT, 'isolated failure'); END;",
    );
    await c.send('question');
    expect(
      await f.conversations.listConversations(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
      ),
      isEmpty,
    );
    expect(c.lastUserMessageSaved, false);
    expect(c.canRetry, true);
    await f.db.customStatement('DROP TRIGGER fail_user');
    await c.retry();
    expect(await roles(), ['USER', 'ASSISTANT']);
  });
  test(
    'retry recovers an assistant COMMIT with lost acknowledgement',
    () async {
      final repo = LostAssistantAcknowledgment(f.db);
      c = ChatTurnCoordinator(
        session: f.session,
        conversations: repo,
        guard: f.guard,
        tutor: tutor,
      );
      await c.initialize();
      await c.send('q');
      expect(c.failure!.code, ChatFailureCode.persistenceFailure);
      expect(await roles(), ['USER', 'ASSISTANT']);
      final calls = tutor.requests.length;
      await c.retry();
      expect(c.failure, isNull);
      expect(c.phase, ChatPhase.ready);
      expect(tutor.requests, hasLength(calls));
      expect(await roles(), ['USER', 'ASSISTANT']);
    },
  );
  test(
    'Cancel after durable assistant COMMIT preserves the completed turn',
    () async {
      final repo = PausedAcknowledgment(f.db);
      c = ChatTurnCoordinator(
        session: f.session,
        conversations: repo,
        guard: f.guard,
        tutor: tutor,
      );
      await c.initialize();
      final operation = c.send('q');
      await repo.committed.future;
      final cancel = c.cancel();
      repo.release.complete();
      await cancel;
      await operation;
      expect(await roles(), ['USER', 'ASSISTANT']);
      expect(c.phase, ChatPhase.ready);
      expect(c.failure, isNull);
      expect(c.canRetry, false);
    },
  );
}
