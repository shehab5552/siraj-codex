import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'package:siraj/features/chat/conversation_history_controller.dart';

import 'support/chat_fixture.dart';
import 'support/fake_tutor.dart';

void main() {
  late ChatFixture f;
  late ConversationHistoryController history;
  final open = <ChatTurnCoordinator>[];
  setUp(() async {
    f = ChatFixture();
    await f.initialize();
    history = ConversationHistoryController(
      session: f.session,
      conversations: f.conversations,
      guard: f.guard,
      tutor: FakeTutor(),
      sources: FakeSourceResolver(),
    );
  });
  tearDown(() async {
    for (final c in open) {
      c.dispose();
    }
    open.clear();
    history.dispose();
    await f.close();
  });
  test('empty history does not create a conversation', () async {
    await history.load();
    expect(history.isLoading, false);
    expect(history.conversations, isEmpty);
  });
  test('saved conversation title reopens and supports a follow-up', () async {
    final c = await history.openDraft();
    expect(c, isNotNull);
    open.add(c!);
    await c.send('السؤال الأول');
    await history.load();
    expect(history.conversations, hasLength(1));
    expect(history.conversations.single.title, 'السؤال الأول');
    final reopened = await history.openConversation(c.conversationId!);
    expect(reopened, isNotNull);
    open.add(reopened!);
    expect(reopened.messages, hasLength(2));
    await reopened.send('متابعة');
    expect(reopened.messages, hasLength(4));
    expect(reopened.conversationId, c.conversationId);
  });
  test('history clears when logout invalidates its live session', () async {
    final c = await history.openDraft();
    open.add(c!);
    await c.send('private');
    await history.load();
    final expired = Completer<void>();
    history.addListener(() {
      if (history.sessionExpired && !expired.isCompleted) expired.complete();
    });
    await f.logout();
    await expired.future.timeout(const Duration(seconds: 2));
    expect(history.conversations, isEmpty);
    expect(await history.openDraft(), isNull);
  });
  test('unowned and deleted conversation IDs cannot reopen', () async {
    final c = await history.openDraft();
    open.add(c!);
    await c.send('question');
    await history.load();
    expect(await history.openConversation('not-owned'), isNull);
    await f.conversations.deleteConversation(
      userId: f.session.userId,
      accountEpoch: f.session.accountEpoch,
      conversationId: c.conversationId!,
    );
    expect(await history.openConversation(c.conversationId!), isNull);
  });
  test(
    'account epoch mismatch never exposes another account history',
    () async {
      history.dispose();
      history = ConversationHistoryController(
        session: const AuthSession(
          userId: 'chat-user',
          accountEpoch: 'old-epoch',
          sessionNonce: 'test-only-nonce',
        ),
        conversations: f.conversations,
        guard: f.guard,
      );
      await history.load();
      expect(history.sessionExpired, true);
      expect(history.conversations, isEmpty);
      expect(await history.openDraft(), isNull);
    },
  );
  test('eleventh new chat preserves the ten-conversation contract', () async {
    for (var i = 0; i < 11; i++) {
      final c = await history.openDraft();
      open.add(c!);
      await c.send('question $i');
    }
    await history.load();
    expect(history.conversations, hasLength(10));
    expect(
      history.conversations.map((c) => c.title),
      isNot(contains('question 0')),
    );
  });
}
