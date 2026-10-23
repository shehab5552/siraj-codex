import '../../integrations/ai/quiz_port.dart';
import 'quiz_decimal.dart';

/// Deterministic reviewed-key scoring. Unrecognized short expressions are not
/// judged wrong, and no LLM is used as an open-ended final judge.
class QuizScorer {
  const QuizScorer({
    NumericPrecisionPort precision = const UnavailableNumericPrecision(),
  }) : _precision = precision;
  final NumericPrecisionPort _precision;
  bool _supportsPrecision(NumericPrecision metadata) {
    try {
      return metadata.isWellFormed && _precision.supports(metadata);
    } catch (_) {
      return false;
    }
  }

  bool referenceIsValid(QuizQuestion q) => switch (q.answerSpec) {
    McqAnswerSpec s =>
      q.options.length >= 2 &&
          q.options.map((o) => o.id).toSet().length == q.options.length &&
          q.options.any((o) => o.id == s.correctOptionId),
    BooleanAnswerSpec s => s.expected != null,
    NumericAnswerSpec s =>
      _supportsPrecision(s.precision) &&
          QuizDecimal.parse(s.referenceValue) != null &&
          QuizDecimal.parse(s.tolerance) != null &&
          !QuizDecimal.parse(s.tolerance)!.coefficient.isNegative &&
          s.acceptedUnits.isNotEmpty &&
          s.acceptedUnits.every((u) => u == u.trim()),
    ShortAnswerSpec s =>
      s.reviewedReference.trim().isNotEmpty &&
          s.allowedVariants.every((a) => a.trim().isNotEmpty),
  };
  QuizFeedback _verdict(bool correct) => QuizFeedback(
    correct ? QuizVerdict.correct : QuizVerdict.incorrect,
    correct
        ? 'إجابة صحيحة وفق المفتاح المراجَع.'
        : 'الإجابة لا تطابق المعيار المراجَع.',
  );
  static const _unknown = QuizFeedback(
    QuizVerdict.undetermined,
    'تعذر الحكم بثقة وفق المعيار المراجَع المتاح.',
  );
  Never _invalid() => throw const QuizFailure(QuizErrorCode.invalidInput);
  QuizFeedback grade(QuizQuestion q, QuizAnswer answer) {
    switch (q.answerSpec) {
      case McqAnswerSpec spec:
        if (answer is! ChoiceAnswer ||
            !q.options.any((o) => o.id == answer.optionId)) {
          _invalid();
        }
        if (!referenceIsValid(q)) return _unknown;
        return _verdict(answer.optionId == spec.correctOptionId);
      case BooleanAnswerSpec spec:
        if (answer is! BooleanAnswer) _invalid();
        if (!referenceIsValid(q)) return _unknown;
        return _verdict(answer.value == spec.expected);
      case NumericAnswerSpec spec:
        if (answer is! NumericAnswer) _invalid();
        final value = QuizDecimal.parse(answer.value);
        if (value == null) _invalid();
        if (!referenceIsValid(q)) return _unknown;
        bool? precise;
        try {
          precise = _precision.accepts(spec.precision, answer);
        } catch (_) {
          return _unknown;
        }
        if (precise == null) return _unknown;
        return _verdict(
          precise &&
              spec.acceptedUnits.contains(answer.unit.trim()) &&
              value.within(
                QuizDecimal.parse(spec.referenceValue)!,
                QuizDecimal.parse(spec.tolerance)!,
              ),
        );
      case ShortAnswerSpec spec:
        if (answer is! ShortAnswer || answer.text.trim().isEmpty) _invalid();
        if (!referenceIsValid(q)) return _unknown;
        final accepted = {
          spec.reviewedReference.trim(),
          ...spec.allowedVariants.map((s) => s.trim()),
        };
        return accepted.contains(answer.text.trim())
            ? _verdict(true)
            : _unknown;
    }
  }
}
