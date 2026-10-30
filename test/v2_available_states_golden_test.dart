import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/core/design/siraj_navigation.dart';
import 'package:siraj/features/quiz/quiz_scorer.dart';
import 'package:siraj/core/design/siraj_v2_components.dart';
import 'package:siraj/features/chat/chat_page.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'package:siraj/features/library/library_contracts.dart';
import 'package:siraj/features/library/library_controller.dart';
import 'package:siraj/features/library/library_page.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/features/quiz/quiz_page.dart';
import 'package:siraj/data/quiz_session_access.dart';
import 'package:siraj/app/presentation/siraj_problem_card.dart';
import 'package:siraj/app/presentation/siraj_problem.dart';
import 'package:siraj/features/quiz/quiz_widgets.dart';
import 'package:siraj/features/quiz/quiz_curriculum.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'support/chat_fixture.dart';
import 'support/fake_tutor.dart';
import 'support/pump_real_future.dart';
import 'support/b11_quiz_fixture.dart';
import 'support/quiz_curriculum_fixture.dart';
import 'unified_library_controller_test.dart' show testBook;

class _Catalog implements ApprovedLibraryCatalog {
  @override
  Future<List<LibraryBook>?> read() async => [
    testBook('alpha', 'A'),
    testBook('beta', 'B'),
  ];
}

/// All answers/catalog entries in this file are explicitly synthetic TEST inputs.
/// These goldens prove presentation and callbacks, never G2/G3 or AI quality.
void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansArabic',
    )..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [const Size(380, 737), const Size(370, 683)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'synthetic available V2 states ${size.width} ${dark ? 'dark' : 'light'}',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final shadows = debugDisableShadows;
          debugDisableShadows = false;
          final f = ChatFixture();
          await t.runAsync(f.initialize);
          final tutor = FakeTutor();
          final pending = Completer<TutorReply>();
          tutor.respond = (_) => pending.future;
          final chat = ChatTurnCoordinator(
            session: f.session,
            conversations: f.conversations,
            guard: f.guard,
            tutor: tutor,
            sources: FakeSourceResolver(),
          );
          await t.runAsync(chat.initialize);
          Future<void> render(Widget page, {int tab = 3}) async {
            await t.pumpWidget(
              RepaintBoundary(
                key: const Key('available-golden'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? SirajTheme.dark() : SirajTheme.light(),
                  home: Directionality(
                    textDirection: TextDirection.rtl,
                    child: SirajAdaptiveNavigation(
                      index: tab,
                      onSelect: (_) {},
                      body: page,
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
          }

          Future<void> capture(String name, {bool animated = false}) async {
            if (animated) {
              await t.pump(const Duration(milliseconds: 200));
            } else {
              for (var i = 0; i < 8; i++) {
                await t.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 15)),
                );
                await t.pump(const Duration(milliseconds: 20));
              }
              await t.pumpAndSettle(
                const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate,
                const Duration(seconds: 2),
              );
            }
            expect(t.takeException(), isNull);
            await expectLater(
              find.byKey(const Key('available-golden')),
              matchesGoldenFile(
                'goldens/reference_v2/state_ar_${dark ? 'dark' : 'light'}_${size.width.toInt()}_$name.png',
              ),
            );
          }

          try {
            await render(ChatPage(coordinator: chat), tab: 1);
            final sending = chat.send('سؤال اصطناعي لاختبار شكل الواجهة');
            await pumpRealFuture(t, tutor.started.future);
            await capture('chat_loading', animated: true);
            expect(find.byKey(const Key('chat-cancel')), findsOneWidget);
            await pumpRealFuture(t, chat.cancel());
            await pumpRealFuture(t, sending);
            await capture('chat_cancelled');
            final req = tutor.requests.single;
            pending.complete(replyFor(req));
            await t.pump();
            expect(
              chat.messages.where((m) => !m.isUser),
              isEmpty,
              reason: 'late response after cancel must not appear',
            );
            tutor.respond = (r) => replyFor(
              r,
              result: TutorResult.answer(
                'نص اصطناعي لاختبار العرض فقط؛ ليس شرحًا تعليميًا.',
                [testSource],
              ),
            );
            await pumpRealFuture(t, chat.send('متابعة اصطناعية للاختبار'));
            await capture('chat_answer');
            await t.ensureVisible(find.byKey(const Key('chat-source-0-0')));
            await t.tap(find.byKey(const Key('chat-source-0-0')));
            await capture('chat_source');
            expect(find.text('مقتطف اختبار اصطناعي'), findsOneWidget);
            await t.tapAt(const Offset(10, 90));
            await t.pumpAndSettle();
            tutor.respond = (r) => replyFor(
              r,
              result: TutorResult.answer(
                'نص جزئي اصطناعي لاختبار الواجهة فقط.',
                [testSource],
                partial: true,
              ),
            );
            await pumpRealFuture(t, chat.send('سؤال جزئي اصطناعي'));
            await capture('chat_partial');
            tutor.respond = (r) => replyFor(
              r,
              result: TutorResult.refusal(TutorReason.noEvidence),
              approved: [],
            );
            await pumpRealFuture(t, chat.send('سؤال رفض اصطناعي'));
            await capture('chat_refusal');
            await render(
              LibraryPage(
                controller: LibraryController(catalog: _Catalog()),
                onOpenResources: () {},
              ),
              tab: 2,
            );
            await capture('library_catalog');
            await t.enterText(
              find.byKey(const Key('library-search')),
              'no-match',
            );
            await capture('library_no_match');
            final setup = QuizSetupController(
              catalog: const TestQuizCurriculum(),
              availability: () => const QuizAvailability.ready('test-r1'),
            );
            await setup.load();
            await render(
              Scaffold(
                appBar: const SirajAppBar(title: 'اختبار مرئي اصطناعي'),
                body: ListView(
                  padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
                  children: [
                    QuizSetupForm(setup: setup, busy: false, onStart: (_) {}),
                  ],
                ),
              ),
            );
            await capture('quiz_setup');
            setup.dispose();
            Future<void> startFromTrustedForm(
              QuizController controller,
              QuizQuestion question,
            ) async {
              final form = t.widget<QuizSetupForm>(find.byType(QuizSetupForm));
              form.setup.selectSubject('synthetic-subject');
              form.setup.selectUnit('synthetic-unit');
              form.setup.selectType(question.type);
              expect(form.setup.selection, isNotNull);
              form.onStart(form.setup.selection!);
              for (
                var i = 0;
                i < 30 && controller.phase != QuizPhase.question;
                i++
              ) {
                await t.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 10)),
                );
                await t.pump(const Duration(milliseconds: 30));
              }
              await t.pumpAndSettle();
              expect(controller.phase, QuizPhase.question);
              expect(
                find.byKey(const Key('quiz-selection-summary')),
                findsOneWidget,
              );
            }

            for (final q in quizQuestions()) {
              final questionController = QuizController(
                session: f.session,
                access: SqliteQuizSessionAccess(
                  database: f.db,
                  session: f.session,
                ),
                port: TestQuizPort()..questions = [q],
                scorer: const QuizScorer(precision: TestNumericPrecision()),
              );
              await pumpRealFuture(t, questionController.initialize());
              await render(
                QuizPage(
                  controller: questionController,
                  curriculum: const TestQuizCurriculum(),
                ),
              );
              await startFromTrustedForm(questionController, q);
              await capture('quiz_${q.type.name}');
              await render(const SizedBox());
              await pumpRealFuture(t, questionController.close());
            }
            final quiz = QuizController(
              session: f.session,
              access: SqliteQuizSessionAccess(
                database: f.db,
                session: f.session,
              ),
              port: TestQuizPort()..questions = [quizQuestions().first],
            );
            await pumpRealFuture(t, quiz.initialize());
            await render(
              QuizPage(
                controller: quiz,
                curriculum: const TestQuizCurriculum(),
              ),
            );
            await startFromTrustedForm(quiz, quizQuestions().first);
            quiz.setDraftAnswer(const ChoiceAnswer('a'));
            await pumpRealFuture(t, quiz.enterReview());
            await capture('quiz_review');
            await t.tap(find.byKey(const Key('quiz-confirm-submit')));
            await capture('quiz_confirm');
            await t.tap(find.text('إلغاء').last);
            await t.pumpAndSettle();
            await render(
              Scaffold(
                appBar: const SirajAppBar(title: 'تشخيص اصطناعي للاختبار'),
                body: ListView(
                  padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
                  children: [
                    SirajProblemCard(
                      problem: const SirajProblem(
                        area: ProblemArea.dataset,
                        action: ProblemAction.resources,
                        arabic:
                            'إصدارات RAG غير متوافقة. أعد تجهيز المجموعة المتوافقة قبل الاسترجاع.',
                        english:
                            'RAG revisions are incompatible. Prepare a compatible group before retrieval.',
                      ),
                      onResources: () {},
                    ),
                    SirajReferenceNotice(
                      text:
                          'رسالة اصطناعية لفحص العرض فقط. لا توجد موارد محملة أو فحص حقيقي للجهاز.',
                      warning: true,
                    ),
                  ],
                ),
              ),
            );
            await pumpRealFuture(t, quiz.close());
            await capture('diagnostics');
            await render(
              Scaffold(
                appBar: const SirajAppBar(title: 'نتيجة اصطناعية للاختبار'),
                body: ListView(
                  padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
                  children: const [
                    QuizSummaryView(
                      summary: QuizSummary(
                        totalPresented: 5,
                        correct: 3,
                        incorrect: 1,
                        undetermined: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
            await capture('quiz_result');
            expect(find.text('3 / 4'), findsOneWidget);
          } finally {
            await t.pumpWidget(const SizedBox());
            chat.dispose();
            await t.pumpAndSettle();
            await t.runAsync(f.close);
            debugDisableShadows = shadows;
          }
        },
      );
    }
  }
}
