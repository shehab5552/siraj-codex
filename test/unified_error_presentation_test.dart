import 'package:siraj/features/chat/chat_models.dart';
import 'package:siraj/integrations/ai/quiz_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/presentation/siraj_problem.dart';
import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/dataset_release_contracts.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/integrations/ai/runtime_contract.dart';

void main() {
  test('missing model and PDF map to actual missing-file evidence', () {
    for (final area in [ProblemArea.llm, ProblemArea.pdf]) {
      final p = SirajProblem.from(
        const ArtifactIntegrityFailure(
          ArtifactIntegrityFailureCode.missingFile,
        ),
        area: area,
      );
      expect(p.action, ProblemAction.redownload);
      expect(p.area, area);
      expect(p.english, isNotEmpty);
      expect(p.arabic, isNotEmpty);
    }
  });
  test('hash and storage errors offer distinct corrective actions', () {
    expect(
      SirajProblem.from(
        const DownloadFailure(DownloadFailureCode.integrityFailure),
      ).action,
      ProblemAction.redownload,
    );
    final p = SirajProblem.from(
      const DownloadFailure(DownloadFailureCode.insufficientStorage),
    );
    expect(p.action, ProblemAction.retry);
    expect(p.english, contains('space'));
  });
  test('incompatible revision and missing validator never claim readiness', () {
    for (final code in [
      DatasetFailureCode.incompatible,
      DatasetFailureCode.candidateChanged,
      DatasetFailureCode.validatorUnavailable,
    ]) {
      final p = SirajProblem.from(DatasetFailure(code));
      expect(p.action, ProblemAction.resources);
      expect(p.english, contains('resource'));
    }
  });
  test('network cause and secret details are not guessed or exposed', () {
    final p = SirajProblem.from(
      const DownloadFailure(
        DownloadFailureCode.networkFailure,
        detail: 'password=/private/local/secret',
      ),
    );
    expect(p.english, contains('HTTPS'));
    expect(p.english, isNot(contains('password')));
    expect(p.arabic, isNot(contains('/private')));
    final unknown = SirajProblem.from(StateError('SECRET /private/path'));
    expect(unknown.english, isNot(contains('SECRET')));
  });
  test(
    'session expiry requires login and incompatible runtime needs resources',
    () {
      expect(
        SirajProblem.from(
          const AuthFailure(AuthFailureCode.sessionInvalid),
        ).action,
        ProblemAction.login,
      );
      expect(
        SirajProblem.from(
          const RuntimeFailure(RuntimeErrorCode.incompatible),
        ).action,
        ProblemAction.resources,
      );
    },
  );
  test('chat and quiz session errors use the shared login recovery',(){
    expect(SirajProblem.from(const ChatFailure(ChatFailureCode.sessionExpired)).action,ProblemAction.login);
    expect(SirajProblem.from(const QuizFailure(QuizErrorCode.sessionExpired)).action,ProblemAction.login);
  });

}
