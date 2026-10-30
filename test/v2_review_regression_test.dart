import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/data/quiz_session_access.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'package:siraj/features/settings/settings_page.dart';
import 'package:siraj/features/chat/conversation_history_controller.dart';
import 'package:siraj/features/chat/conversation_history_page.dart';
import 'support/auth_test_marker.dart';
import 'support/chat_fixture.dart';
import 'support/b11_quiz_fixture.dart';

void main() {
  test(
    'quiz view identity exposes no reviewed session and cannot alias a reused provider ID',
    () async {
      final f = ChatFixture();
      await f.initialize();
      final port = TestQuizPort();
      port.response = (r) => QuizSession(
        id: 'reused-provider-id',
        requestId: r.requestId,
        userId: r.userId,
        accountEpoch: r.accountEpoch,
        datasetRevision: r.datasetRevision,
        questions: [quizQuestions().first],
      );
      final c = QuizController(
        session: f.session,
        access: SqliteQuizSessionAccess(database: f.db, session: f.session),
        port: port,
      );
      try {
        await c.initialize();
        await c.start('synthetic');
        final first = c.sessionIdentity;
        expect(first, isNotNull);
        expect(
          first,
          isNot(isA<QuizSession>()),
          reason:
              'the UI must never retain reviewed questions/keys through an identity handle',
        );
        await c.end();
        expect(c.sessionIdentity, isNull);
        await c.start('synthetic again');
        expect(
          identical(first, c.sessionIdentity),
          isFalse,
          reason: 'provider IDs do not authorize stale UI metadata',
        );
      } finally {
        await c.close();
        c.dispose();
        await f.close();
      }
    },
  );
  testWidgets('history places its open action below actual saved content', (
    t,
  ) async {
    final f = ChatFixture();
    await t.runAsync(f.initialize);
    await t.runAsync(
      () => f.conversations.saveFirstUserMessage(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: 'review-history',
        messageId: 'review-user',
        question: 'سؤال اصطناعي لاختبار التخطيط',
        nowUtc: ChatFixture.stamp,
        sessionNonceHash: f.nonceHash,
      ),
    );
    try {
      await t.pumpWidget(
        MaterialApp(
          theme: SirajTheme.light(),
          home: ConversationHistoryPage(
            controller: ConversationHistoryController(
              session: f.session,
              conversations: f.conversations,
              guard: f.guard,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.byKey(const Key('history-open-review-history'))).dy,
        greaterThan(
          t.getBottomLeft(find.text('سؤال اصطناعي لاختبار التخطيط')).dy,
        ),
      );
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.runAsync(f.close);
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
      'account dialogs preserve V2 warnings and danger palette dark=$dark',
      (t) async {
        final runtime = DatabaseRuntime(
          createDatabase: () => AppDatabase.forTesting(NativeDatabase.memory()),
        );
        final session = AppSessionController(
          runtime: runtime,
          markerStore: ControlledMarker(),
        );
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: dark ? SirajTheme.dark() : SirajTheme.light(),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: SettingsPage(session: session, onOpenResources: () {}),
              ),
            ),
          );
          await t.pumpAndSettle();
          final deleteButton = find.descendant(
            of: find.byKey(const Key('settings-delete')),
            matching: find.byType(OutlinedButton),
          );
          expect(
            t
                .widget<OutlinedButton>(deleteButton)
                .style!
                .foregroundColor!
                .resolve({}),
            const Color(0xFFB72039),
          );
          await t.ensureVisible(find.byKey(const Key('settings-logout')));
          await t.tap(find.byKey(const Key('settings-logout')));
          await t.pumpAndSettle();
          expect(find.textContaining('لن تُحفظ ردود متأخرة'), findsOneWidget);
          await t.tap(find.text('إلغاء').last);
          await t.pumpAndSettle();
          await t.ensureVisible(find.byKey(const Key('settings-delete')));
          await t.tap(find.byKey(const Key('settings-delete')));
          await t.pumpAndSettle();
          expect(find.textContaining('LLM وRAG وPDF'), findsOneWidget);
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const Key('confirm-account-action')),
                )
                .onPressed,
            isNull,
          );
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          session.dispose();
          await runtime.close();
        }
      },
    );
  }
}
