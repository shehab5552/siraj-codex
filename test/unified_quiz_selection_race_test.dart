import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/quiz/quiz_access.dart';
import 'package:siraj/features/quiz/quiz_controller.dart';
import 'package:siraj/features/quiz/quiz_curriculum.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'support/b11_quiz_fixture.dart';
import 'support/chat_fixture.dart';
import 'support/quiz_curriculum_fixture.dart';

class _Access implements QuizAccessPort {
  Completer<bool>? pending;
  @override
  Future<bool> isCurrent() => pending?.future ?? Future.value(true);
  @override
  Stream<bool> watchValidity() => const Stream.empty();
}

void main() {
  test(
    'catalog selection cannot cross a revision change during session validation',
    () async {
      final db = ChatFixture();
      await db.initialize();
      final access = _Access();
      final port = TestQuizPort();
      final c = QuizController(session: db.session, access: access, port: port);
      try {
        await c.initialize();
        final catalog = (await const TestQuizCurriculum().read())!;
        access.pending = Completer<bool>();
        final started = c.startSelection(
          QuizSelection(
            catalog: catalog,
            scope: const QuizScope(
              subjectId: 'synthetic-subject',
              unitId: 'synthetic-unit',
            ),
            type: QuizQuestionType.mcq,
            count: 1,
          ),
        );
        port.availability = const QuizAvailability.ready('test-r2');
        access.pending!.complete(true);
        await started;
        expect(port.requests, isEmpty);
        expect(c.phase, QuizPhase.idle);
        expect(c.error, QuizErrorCode.notAvailable);
      } finally {
        await c.close();
        c.dispose();
        await db.close();
      }
    },
  );
}
