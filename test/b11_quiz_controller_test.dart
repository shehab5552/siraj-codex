import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/quiz_session_access.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/features/quiz/quiz_access.dart';
import 'package:siraj/features/quiz/quiz_scorer.dart';
import 'package:siraj/features/quiz/quiz_cleanup_owner.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'support/chat_fixture.dart';
import 'support/b11_quiz_fixture.dart';

class BrokenQuizWatch implements QuizAccessPort {
  @override
  Future<bool> isCurrent() async => true;
  @override
  Stream<bool> watchValidity() => throw StateError('test-only watch failure');
}

void main() {
  late ChatFixture db;
  late TestQuizPort port;
  late QuizController controller;
  var serial = 0;
  setUp(() async {
    db = ChatFixture();
    await db.initialize();
    port = TestQuizPort();
    serial = 0;
    controller = QuizController(
      session: db.session,
      access: SqliteQuizSessionAccess(database: db.db, session: db.session),
      port: port,
      scorer: const QuizScorer(precision: TestNumericPrecision()),
      newId: () => 'quiz-${serial++}',
    );
    await controller.initialize();
  });
  tearDown(() async {
    await controller.close();
    controller.dispose();
    await db.close();
  });
  Future<void> started() async {
    for (var i = 0; i < 100 && port.requests.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(port.requests.length, 1);
  }

  test(
    'four question types score in RAM, undetermined excluded from judgeable',
    () async {
      await controller.start('synthetic quiz', desiredCount: 4);
      expect(controller.phase, QuizPhase.question);
      await controller.submit(const ChoiceAnswer('a'));
      controller.next();
      await controller.submit(const BooleanAnswer(false));
      controller.next();
      await controller.submit(const NumericAnswer('1.25', unit: 'm'));
      controller.next();
      await controller.submit(const ShortAnswer('unreviewed alternative'));
      controller.next();
      expect(controller.phase, QuizPhase.summary);
      expect(controller.summary?.correct, 2);
      expect(controller.summary?.incorrect, 1);
      expect(controller.summary?.undetermined, 1);
      expect(controller.summary?.judgeable, 3);
      expect(await db.db.customSelect('SELECT * FROM message').get(), isEmpty);
      expect(
        await db.db.customSelect('SELECT * FROM conversation').get(),
        isEmpty,
      );
      await controller.end();
      expect(controller.summary, null);
      expect(controller.question, null);
      expect(controller.phase, QuizPhase.idle);
      expect(port.discarded.length, 1);
    },
  );
  test('invalid numeric input does not create a verdict', () async {
    port.questions = [quizQuestions()[2]];
    await controller.start('test');
    await controller.submit(const NumericAnswer('NaN', unit: 'm'));
    expect(controller.feedback, null);
    expect(controller.error, QuizErrorCode.invalidInput);
    await controller.submit(const NumericAnswer('1.25', unit: 'm'));
    expect(controller.feedback?.verdict, QuizVerdict.correct);
  });
  test(
    'missing reviewed precision adapter rejects numeric items before display',
    () async {
      port.questions = [quizQuestions()[2]];
      final c = QuizController(
        session: db.session,
        access: SqliteQuizSessionAccess(database: db.db, session: db.session),
        port: port,
      );
      try {
        await c.initialize();
        await c.start('test');
        expect(c.question, null);
        expect(c.error, QuizErrorCode.invalidResponse);
      } finally {
        await c.close();
        c.dispose();
      }
    },
  );
  test('duplicate submit cannot change first verdict or counts', () async {
    await controller.start('test');
    await Future.wait([
      controller.submit(const ChoiceAnswer('a')),
      controller.submit(const ChoiceAnswer('b')),
    ]);
    expect(controller.feedback?.verdict, QuizVerdict.correct);
  });
  test('malformed or bank-only session never reaches display', () async {
    final original = quizQuestions().first;
    port.questions = [
      QuizQuestion(
        id: original.id,
        stem: original.stem,
        answerSpec: original.answerSpec,
        sources: original.sources,
        options: original.options,
        origin: QuizOrigin.bankExample,
      ),
    ];
    await controller.start('test');
    expect(controller.question, null);
    expect(controller.error, QuizErrorCode.invalidResponse);
  });
  test('mixed dataset revision is rejected before question display', () async {
    port.questions = [
      QuizQuestion(
        origin: QuizOrigin.llmGenerated,
        id: 'bad',
        stem: 'TEST',
        answerSpec: const BooleanAnswerSpec(true),
        sources: [
          const SourceReference(
            packId: 'test',
            chunkId: 'test',
            datasetRevision: 'other',
          ),
        ],
      ),
    ];
    await controller.start('test');
    expect(controller.question, null);
    expect(controller.error, QuizErrorCode.invalidResponse);
  });
  test('requested count cannot silently become an incomplete quiz', () async {
    await controller.start('test', desiredCount: 5);
    expect(controller.question, null);
    expect(controller.error, QuizErrorCode.notAvailable);
  });
  test(
    'cancel discards late returned session without restoring private UI',
    () async {
      port.paused = Completer<QuizSession>();
      final pending = controller.start('test');
      await started();
      final r = port.requests.single;
      await controller.end();
      port.paused!.complete(port.sessionFor(r));
      await pending;
      expect(controller.question, null);
      expect(controller.phase, QuizPhase.idle);
      expect(port.discarded.length, 1);
    },
  );
  test('logout immediately clears a visible quiz', () async {
    await controller.start('test');
    await db.logout();
    for (
      var i = 0;
      i < 100 && controller.phase != QuizPhase.sessionExpired;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(controller.phase, QuizPhase.sessionExpired);
    expect(controller.question, null);
    expect(controller.summary, null);
  });
  test('delete while creating prevents foreign late session display', () async {
    port.paused = Completer<QuizSession>();
    final pending = controller.start('test');
    await started();
    final r = port.requests.single;
    await db.users.deleteAccount(
      userId: db.session.userId,
      accountEpoch: db.session.accountEpoch,
    );
    port.paused!.complete(port.sessionFor(r));
    await pending;
    expect(controller.question, null);
    expect(controller.phase, QuizPhase.sessionExpired);
  });
  test(
    'generation failure retains no questions and allows explicit retry',
    () async {
      port.failure = const QuizFailure(QuizErrorCode.generationRejected);
      await controller.start('test');
      expect(controller.question, null);
      expect(controller.error, QuizErrorCode.generationRejected);
      port.failure = null;
      await controller.start('test again');
      expect(controller.phase, QuizPhase.question);
      expect(port.requests.length, 2);
    },
  );
  test(
    'foreign session is rejected and its own generation request is cancelled',
    () async {
      port.response = (r) => QuizSession(
        id: 'foreign',
        requestId: r.requestId,
        userId: 'other-user',
        accountEpoch: r.accountEpoch,
        datasetRevision: r.datasetRevision,
        questions: quizQuestions(),
      );
      await controller.start('test');
      expect(controller.question, null);
      expect(controller.error, QuizErrorCode.invalidResponse);
      expect(port.cancelled, [port.requests.single.requestId]);
    },
  );
  test(
    'failed resource discard supports explicit cleanup retry without retaining quiz content',
    () async {
      await controller.start('test');
      port.failDiscard = true;
      await controller.end();
      await Future<void>.delayed(Duration.zero);
      expect(controller.question, null);
      expect(controller.summary, null);
      expect(controller.error, QuizErrorCode.runtimeFailed);
      port.failDiscard = false;
      await controller.retryCleanup();
      await controller.start('new quiz');
      expect(controller.phase, QuizPhase.question);
      expect(port.discarded.length, 2);
    },
  );
  test(
    'watch startup failure is fail closed rather than an unhandled initialization error',
    () async {
      final c = QuizController(
        session: db.session,
        access: BrokenQuizWatch(),
        port: port,
      );
      try {
        await c.initialize();
        expect(c.phase, QuizPhase.sessionExpired);
        expect(c.question, null);
      } finally {
        await c.close();
        c.dispose();
      }
    },
  );
  test('cleanup can be retried after controller close and disposal', () async {
    final c = QuizController(
      session: db.session,
      access: SqliteQuizSessionAccess(database: db.db, session: db.session),
      port: port,
      scorer: const QuizScorer(precision: TestNumericPrecision()),
    );
    await c.initialize();
    await c.start('test');
    port.failDiscard = true;
    await c.close();
    c.dispose();
    expect(c.needsCleanupRetry, true);
    port.failDiscard = false;
    await c.retryCleanup();
    expect(c.needsCleanupRetry, false);
    expect(port.discarded.length, 2);
  });
  test(
    'app-scoped owner can recover cleanup after quiz controller is gone',
    () async {
      final owner = QuizCleanupOwner();
      final c = QuizController(
        session: db.session,
        access: SqliteQuizSessionAccess(database: db.db, session: db.session),
        port: port,
        cleanup: owner,
        scorer: const QuizScorer(precision: TestNumericPrecision()),
      );
      await c.initialize();
      await c.start('test');
      port.failDiscard = true;
      await c.close();
      c.dispose();
      expect(owner.needsRetry, true);
      port.failDiscard = false;
      await owner.retry();
      expect(owner.needsRetry, false);
      expect(port.discarded.length, 2);
    },
  );
}
