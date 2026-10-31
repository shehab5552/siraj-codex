import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/quiz_session_access.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/features/quiz/quiz_page.dart';
import 'support/b11_quiz_fixture.dart';
import 'support/quiz_curriculum_fixture.dart';
import 'support/chat_fixture.dart';

void main() {
  testWidgets(
    'trusted scope, answer review edit and confirmed submit use RAM',
    (t) async {
      final db = ChatFixture();
      await db.initialize();
      final port = TestQuizPort()..questions = [quizQuestions().first];
      final c = QuizController(
        session: db.session,
        access: SqliteQuizSessionAccess(database: db.db, session: db.session),
        port: port,
      );
      try {
        await t.pumpWidget(
          MaterialApp(
            home: QuizPage(
              controller: c,
              curriculum: const TestQuizCurriculum(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.textContaining('جاهزة مراجعة'), findsNothing);
        await t.tap(find.byKey(const Key('quiz-subject')));
        await t.pumpAndSettle();
        await t.tap(find.text('مادة اصطناعية').last);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('quiz-unit-selector')));
        await t.pumpAndSettle();
        await t.tap(find.text('وحدة اصطناعية').last);
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.byKey(const Key('quiz-start')), 160);
        await t.ensureVisible(find.byKey(const Key('quiz-start')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('quiz-start')));
        await t.pumpAndSettle();
        expect(port.requests.single.scope?.unitId, 'synthetic-unit');
        expect(port.requests.single.desiredCount, 1);
        await t.tap(find.text('Synthetic A'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('quiz-next')));
        await t.pumpAndSettle();
        expect(c.phase, QuizPhase.review);
        expect(c.summary, isNull);
        await t.tap(find.byKey(const Key('quiz-edit-0')));
        await t.pumpAndSettle();
        expect(c.draftAnswer, isNotNull);
        await t.tap(find.byKey(const Key('quiz-next')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('quiz-confirm-submit')));
        await t.pumpAndSettle();
        expect(c.phase, QuizPhase.review);
        await t.tap(find.byKey(const Key('quiz-final-confirm')));
        await t.pumpAndSettle();
        expect(c.summary?.correct, 1);
        expect(
          await db.db.customSelect('SELECT * FROM conversation').get(),
          isEmpty,
        );
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = c.close().then((_) {
          closed = true;
        });
        for (var i = 0; i < 100 && !closed; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(closed, isTrue);
        await closing;
        await t.pumpAndSettle();
        await db.close();
      }
    },
  );
}
