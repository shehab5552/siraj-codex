import 'support/quiz_curriculum_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/app/resource_preparation_binding.dart';
import 'package:siraj/app/siraj_app.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/resources/dataset_preparation.dart';
import 'package:siraj/features/resources/download_service.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'support/auth_test_marker.dart';
import 'support/b12_dataset_fixture.dart';

class _Appearance implements AppPreferencesStore {
  @override
  Future<AppPreferences> read() async =>
      const AppPreferences(onboardingComplete: true);
  @override
  Future<void> write(AppPreferences value) async {}
}

void main() {
  late DatasetFixture f;
  setUp(() async {
    f = DatasetFixture();
    await f.initialize();
  });
  tearDown(() async {
    await f.close();
  });
  testWidgets(
    'normal app composition delivers guarded resource binding to UI',
    (t) async {
      final runtime = DatabaseRuntime(createDatabase: () => f.db);
      final auth = AppSessionController(
        runtime: runtime,
        markerStore: ControlledMarker(),
        passwordHasher: PasswordHasher(iterations: 2),
      );
      await t.runAsync(() async {
        await auth.initialize();
        await auth.createAccount(
          username: 'synthetic',
          password: 'synthetic',
          confirmation: 'synthetic',
        );
      });
      final c = DatasetPreparationCoordinator(
        downloads: DownloadService(
          appSupportDirectory: f.support,
          spaceProbe: f.space,
          validator: const ResourceDownloadValidator(),
        ),
        manager: f.manager,
      );
      final prefs = AppPreferencesController(_Appearance());
      await prefs.ready;
      try {
        await t.pumpWidget(
          SirajApp(
            sessionController: auth,
            curriculum: const TestQuizCurriculum(),
            preferences: prefs,
            resourcePreparation: ResourcePreparationBinding(
              coordinator: c,
              revision: 'r1',
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('open-resource-status')));
        await t.tap(find.byKey(const Key('open-resource-status')));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('تجهيز Dataset المعتمد'), 160);
        await t.pumpAndSettle();
        expect(find.text('تجهيز Dataset المعتمد'), findsOneWidget);
        expect(
          find.byKey(const Key('resource-catalog-unavailable')),
          findsNothing,
        );
        await t.tap(find.byType(BackButton));
        await t.pumpAndSettle();
        await t.tap(find.text('اختبر معلوماتك').last);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('quiz-subject')), findsOneWidget);
        await t.tap(find.text('الرئيسية').last);
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const Key('open-resource-status')));
        await t.tap(find.byKey(const Key('open-resource-status')));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(find.text('بدء تجهيز Dataset'), 160);
        await t.ensureVisible(find.text('بدء تجهيز Dataset'));
        await t.pumpAndSettle();
        await t.tap(find.text('بدء تجهيز Dataset'));
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.runAsync(() => auth.logout());
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const Key('login-submit')), findsOneWidget);
        expect(c.phase, DatasetPreparationPhase.idle);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        auth.dispose();
        prefs.dispose();
        c.dispose();
      }
    },
  );
}
