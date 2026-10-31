import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/quiz_session_access.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/features/quiz/quiz_scorer.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'support/chat_fixture.dart';
import 'support/b11_quiz_fixture.dart';

void main() {
  late ChatFixture db;
  late QuizController c;
  late TestQuizPort port;
  setUp(() async {
    db = ChatFixture();
    await db.initialize();
    port = TestQuizPort();
    c = QuizController(
      session: db.session,
      access: SqliteQuizSessionAccess(database: db.db, session: db.session),
      port: port,
      scorer: const QuizScorer(precision: TestNumericPrecision()),
    );
    await c.initialize();
    await c.start('synthetic');
  });
  tearDown(() async {
    await c.close();
    c.dispose();
    await db.close();
  });
  test(
    'answers survive navigation and review without exposing score',
    () async {
      c.setDraftAnswer(const ChoiceAnswer('a'));
      await c.goToQuestion(1);
      c.setDraftAnswer(const BooleanAnswer(false));
      await c.goToQuestion(0);
      expect((c.draftAnswer as ChoiceAnswer).optionId, 'a');
      expect(c.feedback, isNull);
      await c.enterReview();
      expect(c.phase, QuizPhase.review);
      expect(c.answeredCount, 2);
      expect(c.summary, isNull);
      await c.goToQuestion(2);
      c.setDraftAnswer(const NumericAnswer('1.25', unit: 'm'));
      await c.goToQuestion(3);
      c.setDraftAnswer(const ShortAnswer('unreviewed'));
      await c.enterReview();
      await c.finishReview();
      expect(c.summary?.correct, 2);
      expect(c.summary?.incorrect, 1);
      expect(c.summary?.undetermined, 1);
      expect(c.summary?.judgeable, 3);
      expect(await db.db.customSelect('SELECT * FROM message').get(), isEmpty);
    },
  );
  test(
    'missing or invalid numeric input cannot be silently graded or discarded',
    () async {
      await c.enterReview();
      await c.finishReview();
      expect(c.phase, QuizPhase.review);
      expect(c.error, QuizErrorCode.invalidInput);
      await c.goToQuestion(2);
      c.setDraftAnswer(const NumericAnswer('invalid'));
      await c.goToQuestion(0);
      await c.goToQuestion(2);
      expect((c.draftAnswer as NumericAnswer).value, 'invalid');
      expect(c.feedback, isNull);
    },
  );
  test(
    'revocation during review clears answers and prevents summary',
    () async {
      c.setDraftAnswer(const ChoiceAnswer('a'));
      await c.enterReview();
      await db.logout();
      await c.finishReview();
      expect(c.phase, QuizPhase.sessionExpired);
      expect(c.summary, isNull);
      expect(c.answeredCount, 0);
    },
  );
  test(
    'delayed input event from prior question cannot overwrite the next',
    () async {
      final oldQuestion = c.question!.id;
      await c.goToQuestion(1);
      c.setDraftAnswerFor(oldQuestion, const ChoiceAnswer('a'));
      expect(c.draftAnswer, isNull);
      c.setDraftAnswerFor(c.question!.id, const BooleanAnswer(true));
      expect(c.draftAnswer, isA<BooleanAnswer>());
    },
  );
}
