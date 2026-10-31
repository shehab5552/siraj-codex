import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/quiz/quiz_curriculum.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';

class _Catalog implements QuizCurriculumPort {
  QuizCurriculumSnapshot? value;
  @override
  Future<QuizCurriculumSnapshot?> read() async => value;
}

QuizCurriculumSnapshot fixture() => QuizCurriculumSnapshot(
  catalogId: 'test-only-catalog',
  datasetRevision: 'test-r1',
  subjects: [
    QuizSubject(
      id: 'a',
      arabicName: 'مادة اصطناعية أ',
      englishName: 'Synthetic A',
      units: [
        const QuizUnit(id: 'a1', arabicName: 'وحدة أ', englishName: 'Unit A'),
      ],
    ),
    QuizSubject(
      id: 'b',
      arabicName: 'مادة اصطناعية ب',
      englishName: 'Synthetic B',
      units: [
        const QuizUnit(id: 'b1', arabicName: 'وحدة ب', englishName: 'Unit B'),
      ],
    ),
  ],
  allowedCounts: {
    for (final type in QuizQuestionType.values) type: [1, 4],
  },
);
void main() {
  test('unavailable official catalog never creates demo subjects', () async {
    final c = QuizSetupController(
      catalog: const UnavailableQuizCurriculum(),
      availability: () => const QuizAvailability.unavailable(),
    );
    await c.load();
    expect(c.snapshot, isNull);
    expect(c.selection, isNull);
    expect(c.canStart, isFalse);
    c.dispose();
  });
  test(
    'changing subject clears unit and count is constrained by service',
    () async {
      final source = _Catalog()..value = fixture();
      final c = QuizSetupController(
        catalog: source,
        availability: () => const QuizAvailability.ready('test-r1'),
      );
      await c.load();
      c.selectSubject('a');
      c.selectUnit('a1');
      c.selectCount(4);
      expect(c.canStart, isTrue);
      c.selectSubject('b');
      expect(c.selection, isNull);
      c.selectUnit('a1');
      expect(c.selection, isNull);
      c.selectUnit('b1');
      expect(c.selection?.scope.unitId, 'b1');
      c.selectCount(99);
      expect(c.canStart, isFalse);
      c.dispose();
    },
  );
  test('revision mismatch cannot be used for quiz generation', () async {
    final source = _Catalog()..value = fixture();
    final c = QuizSetupController(
      catalog: source,
      availability: () => const QuizAvailability.ready('different-r2'),
    );
    await c.load();
    c.selectSubject('a');
    c.selectUnit('a1');
    expect(c.canStart, isFalse);
    expect(c.resourcesReady, isFalse);
    c.dispose();
  });
}
