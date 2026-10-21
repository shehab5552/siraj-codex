import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/chat/chat_page.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';

void main() {
  group('B-05 chat UI: authenticated draft only', () {
    late AppDatabase db;
    late UserRepository users;
    late ConversationRepository conversations;
    late AuthSession session;
    late ConversationDraftController draft;
    var serial = 0;

    setUp(() async {
      serial = 0;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      users = UserRepository(db);
      conversations = ConversationRepository(db);
      session = const AuthSession(
        userId: 'b05-test-user',
        accountEpoch: 'b05-test-epoch',
        sessionNonce: 'b05-disposable-nonce',
      );
      await users.create(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        usernameNormalized: 'b05',
        usernameDisplay: 'B05',
        passwordSalt: Uint8List.fromList([1, 2]),
        passwordHash: Uint8List.fromList([3, 4]),
        passwordParamsJson: '{"iterations":1000}',
        nowUtc: '2026-10-22T00:00:00.000Z',
      );
      final digest = await Sha256().hash(utf8.encode(session.sessionNonce));
      await users.setNonceHash(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        hash: Uint8List.fromList(digest.bytes),
        nowUtc: '2026-10-22T00:00:00.000Z',
      );
      draft = ConversationDraftController(
        conversations: conversations,
        guard: SessionGuard(users),
        newId: () => 'b05-ui-${serial++}',
        clock: () => DateTime.utc(2026, 10, 22),
      );
    });

    tearDown(() async => db.close());

    Future<int> savedCount() async => (await conversations.listConversations(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
    )).length;

    Future<void> render(WidgetTester tester, {bool authenticated = true}) =>
        tester.pumpWidget(
          MaterialApp(
            home: authenticated
                ? ChatPage(draftController: draft, session: session)
                : const ChatPage(),
          ),
        );

    testWidgets('opening a verified draft does not create a DB row', (
      tester,
    ) async {
      await render(tester);
      expect(find.textContaining('محادثة جديدة مؤقتة'), findsOneWidget);
      expect(find.byKey(const Key('chat-send-disabled')), findsOneWidget);
      expect(await savedCount(), 0);
    });

    testWidgets('verified first question persists once; no fake AI answer', (
      tester,
    ) async {
      await render(tester);
      await tester.enterText(
        find.byKey(const Key('chat-question-input')),
        ' ما وظيفة الخلية؟ ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send-enabled')));
      await tester.pumpAndSettle();
      expect(await savedCount(), 1);
      expect(find.byKey(const Key('chat-saved-question')), findsOneWidget);
      expect(find.text('ما وظيفة الخلية؟'), findsOneWidget);
      expect(find.byKey(const Key('chat-no-ai-answer')), findsOneWidget);
      expect(find.byKey(const Key('chat-send-disabled')), findsOneWidget);
      final rows = await conversations.listMessages(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        conversationId: draft.conversationId!,
      );
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('role'), 'USER');
    });

    testWidgets('preview without supplied session cannot persist', (
      tester,
    ) async {
      await render(tester, authenticated: false);
      final input = tester.widget<TextField>(
        find.byKey(const Key('chat-question-input')),
      );
      expect(input.enabled, false);
      expect(await savedCount(), 0);
    });

    testWidgets('invalidated session shows error and saves nothing', (
      tester,
    ) async {
      await render(tester);
      await users.invalidateNonce(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        nowUtc: '2026-10-22T00:00:01.000Z',
      );
      await tester.enterText(
        find.byKey(const Key('chat-question-input')),
        'سؤال',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send-enabled')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-save-error')), findsOneWidget);
      expect(await savedCount(), 0);
      expect(draft.isTemporary, isTrue);
    });
  });
}
