import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/quiz_session_access.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/features/quiz/quiz_page.dart';
import 'package:siraj/features/quiz/quiz_scorer.dart';
import 'package:siraj/features/home/home_page.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';
import 'support/fake_tutor.dart';
import 'support/chat_fixture.dart';
import 'support/b11_quiz_fixture.dart';

void main() {
  late ChatFixture db;
  late TestQuizPort port;
  final opened = <QuizController>[];
  var serial = 0;
  setUp(() async {
    db = ChatFixture();
    await db.initialize();
    port = TestQuizPort();
    serial = 0;
  });
  tearDown(() async {
    opened.clear();
    await db.close();
  });
  QuizController create({QuizPort? selected, SourceResolverPort? sources}) {
    final c = QuizController(
      session: db.session,
      access: SqliteQuizSessionAccess(database: db.db, session: db.session),
      port: selected ?? port,
      scorer: const QuizScorer(precision: TestNumericPrecision()),
      sources: sources ?? const UnavailableSourceResolver(),
      newId: () => 'quiz-${serial++}',
    );
    opened.add(c);
    return c;
  }

  void quizWidgetTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = Future.wait(opened.map((c) => c.close())).then((_) {
          closed = true;
        });
        for (var i = 0; i < 100 && !closed; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          closed,
          true,
          reason:
              'Quiz controllers must drain while the Flutter fake clock is active',
        );
        await closing;
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      }
    });
  }

  Future<void> render(WidgetTester t, QuizController c) async {
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF254A65)),
          useMaterial3: true,
        ),
        home: QuizPage(controller: c),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> generate(WidgetTester t) async {
    await t.enterText(
      find.byKey(const Key('quiz-request')),
      'طلب اختبار اصطناعي',
    );
    await t.ensureVisible(find.byKey(const Key('quiz-start')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-start')));
    await t.pumpAndSettle();
  }

  quizWidgetTest(
    'quiz renders RTL and all four input types without scientific fakes in production',
    (t) async {
      final c = create();
      await render(t, c);
      expect(
        Directionality.of(t.element(find.byKey(const Key('quiz-request')))),
        TextDirection.rtl,
      );
      await generate(t);
      expect(find.text('SYNTHETIC MCQ'), findsOneWidget);
      await t.tap(find.text('Synthetic A'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('quiz-submit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('quiz-next')));
      await t.pumpAndSettle();
      expect(find.text('SYNTHETIC BOOLEAN'), findsOneWidget);
      await t.tap(find.text('خطأ'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('quiz-submit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('quiz-next')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('quiz-number')), findsOneWidget);
      await t.enterText(find.byKey(const Key('quiz-number')), '1.25');
      await t.enterText(find.byKey(const Key('quiz-unit')), 'm');
      await t.tap(find.byKey(const Key('quiz-submit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('quiz-next')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('quiz-short-answer')),
        'صياغة غير مراجعة',
      );
      await t.tap(find.byKey(const Key('quiz-submit')));
      await t.pumpAndSettle();
      expect(find.textContaining('تعذر الحكم'), findsWidgets);
      await t.tap(find.byKey(const Key('quiz-next')));
      await t.pumpAndSettle();
      expect(find.text('2 صحيحة'), findsOneWidget);
      expect(find.text('1 خاطئة'), findsOneWidget);
      expect(find.text('1 تعذر الحكم'), findsOneWidget);
      expect(find.textContaining('3 أسئلة محسومة'), findsOneWidget);
      expect(find.text('2/4'), findsNothing);
      await t.tap(find.byKey(const Key('quiz-end')));
      await t.pumpAndSettle();
      expect(c.summary, null);
      expect(find.text('SYNTHETIC MCQ'), findsNothing);
    },
  );
  quizWidgetTest('unavailable model renders error without bank-only quiz', (
    t,
  ) async {
    await render(t, create(selected: const UnavailableQuizPort()));
    await generate(t);
    expect(find.textContaining('النموذج'), findsWidgets);
    expect(find.text('SYNTHETIC MCQ'), findsNothing);
  });
  quizWidgetTest('logout clears visible question and controls', (t) async {
    await render(t, create());
    await generate(t);
    await db.logout();
    await t.pumpAndSettle();
    expect(find.text('SYNTHETIC MCQ'), findsNothing);
    expect(find.textContaining('انتهت صلاحية الجلسة'), findsWidgets);
  });
  quizWidgetTest('question layout survives narrow RTL with large text', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = create();
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: QuizPage(controller: c),
      ),
    );
    await t.pumpAndSettle();
    await generate(t);
    expect(port.requests.length, 1);
    expect(find.text('SYNTHETIC MCQ'), findsOneWidget);
    expect(t.takeException(), null);
  });
  quizWidgetTest('unauthenticated Home preview never exposes Quiz action', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.byKey(const Key('open-quiz')), findsNothing);
  });
  quizWidgetTest(
    'authenticated Home routes Quiz action through its supplied callback',
    (t) async {
      var openedQuiz = false;
      await t.pumpWidget(
        MaterialApp(
          home: HomePage(
            onOpenChat: () {},
            onOpenQuiz: () {
              openedQuiz = true;
            },
          ),
        ),
      );
      await t.ensureVisible(find.byKey(const Key('open-quiz')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('open-quiz')));
      expect(openedQuiz, true);
    },
  );
  quizWidgetTest('source display uses exact metadata without fabricated page', (
    t,
  ) async {
    final sources = FakeSourceResolver()
      ..respond = (reference) => ResolvedSource(
        reference: reference,
        snippet: 'SYNTHETIC QUIZ SOURCE',
        subject: 'test subject',
      );
    await render(t, create(sources: sources));
    await generate(t);
    await t.ensureVisible(find.byKey(const Key('quiz-source-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-source-0')));
    await t.pumpAndSettle();
    expect(find.text('SYNTHETIC QUIZ SOURCE'), findsOneWidget);
    expect(find.textContaining('صفحة'), findsNothing);
  });
  quizWidgetTest(
    'logout removes a source snippet even while its dialog is open',
    (t) async {
      final sources = FakeSourceResolver()
        ..respond = (reference) => ResolvedSource(
          reference: reference,
          snippet: 'PRIVATE SYNTHETIC SNIPPET',
        );
      await render(t, create(sources: sources));
      await generate(t);
      await t.ensureVisible(find.byKey(const Key('quiz-source-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('quiz-source-0')));
      await t.pumpAndSettle();
      expect(find.text('PRIVATE SYNTHETIC SNIPPET'), findsOneWidget);
      await db.logout();
      await t.pumpAndSettle();
      expect(find.text('PRIVATE SYNTHETIC SNIPPET'), findsNothing);
    },
  );
  quizWidgetTest('late source cannot appear over the next question', (t) async {
    final pending = Completer<ResolvedSource?>();
    final sources = FakeSourceResolver()..respond = (_) => pending.future;
    await render(t, create(sources: sources));
    await generate(t);
    await t.tap(find.text('Synthetic A'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-submit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-source-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-next')));
    await t.pumpAndSettle();
    pending.complete(
      const ResolvedSource(
        reference: quizRef,
        snippet: 'STALE QUESTION SOURCE',
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('SYNTHETIC BOOLEAN'), findsOneWidget);
    expect(find.text('STALE QUESTION SOURCE'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
  quizWidgetTest('late source cannot appear over the summary', (t) async {
    port.questions = [quizQuestions().first];
    final pending = Completer<ResolvedSource?>();
    final sources = FakeSourceResolver()..respond = (_) => pending.future;
    await render(t, create(sources: sources));
    await generate(t);
    await t.tap(find.text('Synthetic A'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-submit')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-source-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('quiz-next')));
    await t.pumpAndSettle();
    pending.complete(
      const ResolvedSource(reference: quizRef, snippet: 'STALE SUMMARY SOURCE'),
    );
    await t.pumpAndSettle();
    expect(find.text('1 صحيحة'), findsOneWidget);
    expect(find.text('STALE SUMMARY SOURCE'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
