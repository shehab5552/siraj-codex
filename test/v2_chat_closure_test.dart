import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/chat/chat_page.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'support/chat_fixture.dart';

void main() {
  testWidgets(
    'draft uses reference empty state and composer without a demo answer',
    (t) async {
      final f = ChatFixture();
      await t.runAsync(f.initialize);
      final chat = ChatTurnCoordinator(
        session: f.session,
        conversations: f.conversations,
        guard: f.guard,
      );
      await t.runAsync(chat.initialize);
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: SirajTheme.light(),
            home: ChatPage(coordinator: chat),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('المساعد التعليمي'), findsOneWidget);
        expect(find.text('ما الذي تريد فهمه اليوم؟'), findsOneWidget);
        expect(find.byKey(const Key('v2-chat-illustration')), findsOneWidget);
        expect(find.byKey(const Key('v2-chat-composer')), findsOneWidget);
        expect(chat.messages, isEmpty);
        expect(find.byKey(const Key('chat-send-enabled')), findsNothing);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await t.runAsync(f.close);
      }
    },
  );
}
