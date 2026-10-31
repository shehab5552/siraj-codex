import 'dart:async';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';

const quizRef = SourceReference(
  packId: 'test-pack',
  chunkId: 'test-chunk',
  datasetRevision: 'test-r1',
);
final testPrecision = NumericPrecision(
  policyId: 'test-only-policy',
  parameters: {'mode': 'synthetic'},
);

/// An explicit synthetic reviewed policy double, never shipped in lib.
class TestNumericPrecision implements NumericPrecisionPort {
  const TestNumericPrecision();
  @override
  bool supports(NumericPrecision precision) =>
      precision.policyId == 'test-only-policy' &&
      precision.parameters['mode'] == 'synthetic';
  @override
  bool? accepts(NumericPrecision precision, NumericAnswer answer) => true;
}

List<QuizQuestion> quizQuestions() => [
  QuizQuestion(
    origin: QuizOrigin.llmGenerated,
    id: 'mcq',
    stem: 'SYNTHETIC MCQ',
    answerSpec: const McqAnswerSpec('a'),
    sources: [quizRef],
    options: [
      const QuizOption('a', 'Synthetic A'),
      const QuizOption('b', 'Synthetic B'),
    ],
  ),
  QuizQuestion(
    origin: QuizOrigin.llmGenerated,
    id: 'boolean',
    stem: 'SYNTHETIC BOOLEAN',
    answerSpec: const BooleanAnswerSpec(true),
    sources: [quizRef],
  ),
  QuizQuestion(
    origin: QuizOrigin.llmGenerated,
    id: 'numeric',
    stem: 'SYNTHETIC NUMERIC',
    answerSpec: NumericAnswerSpec(
      referenceValue: '1.25',
      tolerance: '0',
      precision: testPrecision,
      acceptedUnits: {'m'},
    ),
    sources: [quizRef],
  ),
  QuizQuestion(
    origin: QuizOrigin.llmGenerated,
    id: 'short',
    stem: 'SYNTHETIC SHORT',
    answerSpec: ShortAnswerSpec(reviewedReference: 'synthetic reference'),
    sources: [quizRef],
  ),
];

class TestQuizPort implements QuizPort {
  @override
  QuizAvailability availability = const QuizAvailability.ready('test-r1');
  final requests = <QuizRequest>[];
  final cancelled = <String>[];
  final discarded = <String>[];
  List<QuizQuestion>? questions;
  Completer<QuizSession>? paused;
  QuizFailure? failure;
  bool failDiscard = false;
  QuizSession Function(QuizRequest)? response;
  QuizSession sessionFor(QuizRequest r) => QuizSession(
    id: 'session-${r.requestId}',
    requestId: r.requestId,
    userId: r.userId,
    accountEpoch: r.accountEpoch,
    datasetRevision: r.datasetRevision,
    questions: questions ?? quizQuestions(),
  );
  @override
  Future<QuizSession> create(QuizRequest request) async {
    requests.add(request);
    if (failure case final f?) throw f;
    return paused != null
        ? paused!.future
        : response?.call(request) ?? sessionFor(request);
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelled.add(requestId);
  }

  @override
  Future<void> discard({
    required String requestId,
    required String sessionId,
  }) async {
    discarded.add(sessionId);
    if (failDiscard) throw const QuizFailure(QuizErrorCode.runtimeFailed);
  }
}
