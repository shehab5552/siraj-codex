import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/quiz/quiz_scorer.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'support/b11_quiz_fixture.dart';

class ControlledPrecision extends TestNumericPrecision {
  ControlledPrecision({this.result, this.fail = false});
  final bool? result;
  final bool fail;
  NumericPrecision? received;
  @override
  bool? accepts(NumericPrecision precision, NumericAnswer answer) {
    received = precision;
    if (fail) throw StateError('test-only policy failure');
    return result;
  }
}

void main() {
  const scorer = QuizScorer(precision: TestNumericPrecision());
  QuizQuestion q(QuizAnswerSpec spec, {List<QuizOption> options = const []}) =>
      QuizQuestion(
        origin: QuizOrigin.llmGenerated,
        id: 'test',
        stem: 'SYNTHETIC TEST QUESTION',
        answerSpec: spec,
        sources: [],
        options: options,
      );
  const options = [
    QuizOption('a', 'Synthetic A'),
    QuizOption('b', 'Synthetic B'),
  ];
  test('MCQ reviewed key determines correct and incorrect', () {
    final question = q(const McqAnswerSpec('a'), options: options);
    expect(
      scorer.grade(question, const ChoiceAnswer('a')).verdict,
      QuizVerdict.correct,
    );
    expect(
      scorer.grade(question, const ChoiceAnswer('b')).verdict,
      QuizVerdict.incorrect,
    );
  });
  test('invalid MCQ key discovered after display is undetermined', () {
    expect(
      scorer
          .grade(
            q(const McqAnswerSpec('missing'), options: options),
            const ChoiceAnswer('a'),
          )
          .verdict,
      QuizVerdict.undetermined,
    );
  });
  test('choice outside displayed options is input error', () {
    expect(
      () => scorer.grade(
        q(const McqAnswerSpec('a'), options: options),
        const ChoiceAnswer('unknown'),
      ),
      throwsA(isA<QuizFailure>()),
    );
  });
  test('Boolean uses reviewed key', () {
    expect(
      scorer
          .grade(q(const BooleanAnswerSpec(true)), const BooleanAnswer(true))
          .verdict,
      QuizVerdict.correct,
    );
    expect(
      scorer
          .grade(q(const BooleanAnswerSpec(true)), const BooleanAnswer(false))
          .verdict,
      QuizVerdict.incorrect,
    );
  });
  test('missing Boolean key never becomes incorrect', () {
    expect(
      scorer
          .grade(q(const BooleanAnswerSpec(null)), const BooleanAnswer(false))
          .verdict,
      QuizVerdict.undetermined,
    );
  });
  QuizQuestion numeric(
    String value,
    String tolerance, {
    Set<String> units = const {'m'},
  }) => q(
    NumericAnswerSpec(
      referenceValue: value,
      tolerance: tolerance,
      precision: testPrecision,
      acceptedUnits: units,
    ),
  );
  test('decimal tolerance includes exact boundary without float error', () {
    final question = numeric('1', '0.01');
    expect(
      scorer.grade(question, const NumericAnswer('1.01', unit: 'm')).verdict,
      QuizVerdict.correct,
    );
    expect(
      scorer
          .grade(question, const NumericAnswer('1.010001', unit: 'm'))
          .verdict,
      QuizVerdict.incorrect,
    );
  });
  test('numeric grading fails closed without a reviewed precision policy', () {
    expect(
      const QuizScorer()
          .grade(numeric('1', '0'), const NumericAnswer('1', unit: 'm'))
          .verdict,
      QuizVerdict.undetermined,
    );
  });
  test(
    'reviewed precision rejection is applied independently of tolerance',
    () {
      final precision = ControlledPrecision(result: false);
      expect(
        QuizScorer(
          precision: precision,
        ).grade(numeric('1', '0'), const NumericAnswer('1', unit: 'm')).verdict,
        QuizVerdict.incorrect,
      );
      expect(identical(precision.received, testPrecision), true);
    },
  );
  for (final fail in [false, true]) {
    test(
      'unknown or failed precision evaluation stays undetermined (throw=$fail)',
      () {
        expect(
          QuizScorer(precision: ControlledPrecision(fail: fail))
              .grade(numeric('1', '0'), const NumericAnswer('1', unit: 'm'))
              .verdict,
          QuizVerdict.undetermined,
        );
      },
    );
  }
  test('unsupported reviewed metadata is not a valid numeric reference', () {
    final question = q(
      NumericAnswerSpec(
        referenceValue: '1',
        tolerance: '0',
        acceptedUnits: {'m'},
        precision: NumericPrecision(policyId: 'unapproved-policy'),
      ),
    );
    expect(scorer.referenceIsValid(question), false);
    expect(
      scorer.grade(question, const NumericAnswer('1', unit: 'm')).verdict,
      QuizVerdict.undetermined,
    );
  });
  test('Arabic digits and decimal separator preserve quantity', () {
    expect(
      scorer
          .grade(numeric('1.25', '0'), const NumericAnswer('١٫٢٥', unit: 'm'))
          .verdict,
      QuizVerdict.correct,
    );
  });
  test('unit aliases are reviewed and case sensitive', () {
    final question = numeric('1', '0', units: {'m', 'م'});
    expect(
      scorer.grade(question, const NumericAnswer('1', unit: 'م')).verdict,
      QuizVerdict.correct,
    );
    expect(
      scorer.grade(question, const NumericAnswer('1', unit: 'M')).verdict,
      QuizVerdict.incorrect,
    );
  });
  test('exponent and negative numeric comparison are exact', () {
    expect(
      scorer
          .grade(numeric('-100', '0', units: {''}), const NumericAnswer('-1e2'))
          .verdict,
      QuizVerdict.correct,
    );
  });
  for (final value in ['', 'NaN', 'Infinity', '1,25', '1e9999999']) {
    test(
      'invalid numeric input $value is not a scientific incorrect answer',
      () {
        expect(
          () => scorer.grade(numeric('1', '0'), NumericAnswer(value)),
          throwsA(
            isA<QuizFailure>().having(
              (e) => e.code,
              'code',
              QuizErrorCode.invalidInput,
            ),
          ),
        );
      },
    );
  }
  test('invalid numeric reference or tolerance is undetermined', () {
    expect(
      scorer
          .grade(numeric('NaN', '0'), const NumericAnswer('1', unit: 'm'))
          .verdict,
      QuizVerdict.undetermined,
    );
    expect(
      scorer
          .grade(numeric('1', '-1'), const NumericAnswer('1', unit: 'm'))
          .verdict,
      QuizVerdict.undetermined,
    );
  });
  test(
    'reviewed short variants match; unreviewed alternative is undetermined',
    () {
      final question = q(
        ShortAnswerSpec(
          reviewedReference: 'synthetic answer',
          allowedVariants: ['reviewed variant'],
        ),
      );
      expect(
        scorer.grade(question, const ShortAnswer('reviewed variant')).verdict,
        QuizVerdict.correct,
      );
      expect(
        scorer
            .grade(question, const ShortAnswer('unreviewed expression'))
            .verdict,
        QuizVerdict.undetermined,
      );
    },
  );
  test('blank short answer and incompatible answer kind are input errors', () {
    expect(
      () => scorer.grade(
        q(ShortAnswerSpec(reviewedReference: 'test')),
        const ShortAnswer(' '),
      ),
      throwsA(isA<QuizFailure>()),
    );
    expect(
      () => scorer.grade(
        q(const BooleanAnswerSpec(true)),
        const ChoiceAnswer('a'),
      ),
      throwsA(isA<QuizFailure>()),
    );
  });
  test(
    'default generator never provides bank questions when model is missing',
    () async {
      const port = UnavailableQuizPort();
      expect(port.availability.isReady, false);
    },
  );
}
