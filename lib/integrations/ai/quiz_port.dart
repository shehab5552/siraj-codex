import 'tutor_contract.dart';

const maxQuizGenerationAttempts = 2;

enum QuizQuestionType { mcq, trueFalse, numeric, shortAnswer }

enum QuizOrigin { llmGenerated, bankExample }

enum QuizErrorCode {
  notAvailable,
  modelRequired,
  generationRejected,
  invalidResponse,
  requestCancelled,
  sessionExpired,
  invalidInput,
  runtimeFailed,
}

class QuizFailure implements Exception {
  const QuizFailure(this.code);
  final QuizErrorCode code;
}

class QuizOption {
  const QuizOption(this.id, this.text);
  final String id, text;
}

sealed class QuizAnswerSpec {
  const QuizAnswerSpec();
  QuizQuestionType get type;
}

class McqAnswerSpec extends QuizAnswerSpec {
  const McqAnswerSpec(this.correctOptionId);
  final String? correctOptionId;
  @override
  QuizQuestionType get type => QuizQuestionType.mcq;
}

class BooleanAnswerSpec extends QuizAnswerSpec {
  const BooleanAnswerSpec(this.expected);
  final bool? expected;
  @override
  QuizQuestionType get type => QuizQuestionType.trueFalse;
}

class NumericAnswerSpec extends QuizAnswerSpec {
  NumericAnswerSpec({
    required this.referenceValue,
    required this.tolerance,
    required this.precision,
    required Iterable<String> acceptedUnits,
  }) : acceptedUnits = Set.unmodifiable(acceptedUnits);

  /// Preserve reviewed decimal text, not a rounded binary floating-point value.
  final String referenceValue, tolerance;
  final NumericPrecision precision;
  final Set<String> acceptedUnits;
  @override
  QuizQuestionType get type => QuizQuestionType.numeric;
}

/// Reviewed A/C policy metadata. This DTO does not choose rounding rules.
class NumericPrecision {
  NumericPrecision({
    required this.policyId,
    Map<String, String> parameters = const {},
  }) : parameters = Map.unmodifiable(parameters);
  final String policyId;
  final Map<String, String> parameters;
  bool get isWellFormed =>
      policyId.trim().isNotEmpty &&
      policyId == policyId.trim() &&
      parameters.entries.every(
        (e) => e.key.trim().isNotEmpty && e.value.trim().isNotEmpty,
      );
}

/// Deterministic adapter to the reviewed precision policy, never an LLM judge.
/// supports must validate the complete metadata, not just recognize its ID.
abstract interface class NumericPrecisionPort {
  bool supports(NumericPrecision precision);
  bool? accepts(NumericPrecision precision, NumericAnswer answer);
}

class UnavailableNumericPrecision implements NumericPrecisionPort {
  const UnavailableNumericPrecision();
  @override
  bool supports(NumericPrecision precision) => false;
  @override
  bool? accepts(NumericPrecision precision, NumericAnswer answer) => null;
}

class ShortAnswerSpec extends QuizAnswerSpec {
  ShortAnswerSpec({
    required this.reviewedReference,
    Iterable<String> allowedVariants = const [],
  }) : allowedVariants = Set.unmodifiable(allowedVariants);
  final String reviewedReference;
  final Set<String> allowedVariants;
  @override
  QuizQuestionType get type => QuizQuestionType.shortAnswer;
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.stem,
    required this.answerSpec,
    required Iterable<SourceReference> sources,
    Iterable<QuizOption> options = const [],
    required this.origin,
  }) : sources = List.unmodifiable(sources),
       options = List.unmodifiable(options);
  final String id, stem;
  final QuizAnswerSpec answerSpec;
  final List<SourceReference> sources;
  final List<QuizOption> options;
  final QuizOrigin origin;
  QuizQuestionType get type => answerSpec.type;
}

sealed class QuizAnswer {
  const QuizAnswer();
}

class ChoiceAnswer extends QuizAnswer {
  const ChoiceAnswer(this.optionId);
  final String optionId;
}

class BooleanAnswer extends QuizAnswer {
  const BooleanAnswer(this.value);
  final bool value;
}

class NumericAnswer extends QuizAnswer {
  const NumericAnswer(this.value, {this.unit = ''});
  final String value, unit;
}

class ShortAnswer extends QuizAnswer {
  const ShortAnswer(this.text);
  final String text;
}

enum QuizVerdict { correct, incorrect, undetermined }

class QuizFeedback {
  const QuizFeedback(this.verdict, this.explanation);
  final QuizVerdict verdict;
  final String explanation;
}

class QuizSession {
  QuizSession({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.accountEpoch,
    required this.datasetRevision,
    required Iterable<QuizQuestion> questions,
  }) : questions = List.unmodifiable(questions);
  final String id, requestId, userId, accountEpoch, datasetRevision;
  final List<QuizQuestion> questions;
}

class QuizRequest {
  const QuizRequest({
    required this.requestId,
    required this.userId,
    required this.accountEpoch,
    required this.text,
    required this.datasetRevision,
    required this.cancellation,
    this.desiredCount,
    this.desiredType,
  });
  final String requestId, userId, accountEpoch, text, datasetRevision;
  final TutorCancellation cancellation;
  final int? desiredCount;
  final QuizQuestionType? desiredType;
}

class QuizAvailability {
  const QuizAvailability.ready(this.datasetRevision) : error = null;
  const QuizAvailability.unavailable([this.error = QuizErrorCode.notAvailable])
    : datasetRevision = null;
  final String? datasetRevision;
  final QuizErrorCode? error;
  bool get isReady =>
      error == null &&
      datasetRevision != null &&
      datasetRevision!.trim().isNotEmpty;
}

/// A's create implements reviewed few-shot→NEW local LLM items→QuestionValidator
/// with MAX_GENERATION_ATTEMPTS=2, and retains resource leases until discard.
/// Product availability requires LLM plus complete RAG/shared embedding ready.
/// No bank-only fallback. Owner IDs never go to the local model prompt.
abstract interface class QuizPort {
  QuizAvailability get availability;
  Future<QuizSession> create(QuizRequest request);
  Future<void> cancel(String requestId);
  Future<void> discard({required String requestId, required String sessionId});
}

class UnavailableQuizPort implements QuizPort {
  const UnavailableQuizPort();
  @override
  QuizAvailability get availability =>
      const QuizAvailability.unavailable(QuizErrorCode.modelRequired);
  @override
  Future<QuizSession> create(QuizRequest request) async =>
      throw const QuizFailure(QuizErrorCode.modelRequired);
  @override
  Future<void> cancel(String requestId) async {}
  @override
  Future<void> discard({
    required String requestId,
    required String sessionId,
  }) async {}
}
