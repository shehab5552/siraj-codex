import 'package:siraj/features/quiz/quiz_curriculum.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';

class TestQuizCurriculum implements QuizCurriculumPort {
  const TestQuizCurriculum();
  @override
  Future<QuizCurriculumSnapshot?> read() async => QuizCurriculumSnapshot(
    catalogId: 'test-only-curriculum',
    datasetRevision: 'test-r1',
    subjects: [
      QuizSubject(
        id: 'synthetic-subject',
        arabicName: 'مادة اصطناعية',
        englishName: 'Synthetic subject',
        units: [
          const QuizUnit(
            id: 'synthetic-unit',
            arabicName: 'وحدة اصطناعية',
            englishName: 'Synthetic unit',
          ),
        ],
      ),
    ],
    allowedCounts: {
      for (final type in QuizQuestionType.values) type: [1],
    },
  );
}
