import 'support/native_results.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/app/siraj_app.dart';

/// Normal main.dart composition, isolated by com.example.siraj.unifiedtest.
/// No Fake Tutor, KDF, Keystore or database is injected into this test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  recordNativeResults(binding, 'application', 1);
  testWidgets(
    'unified real Android startup auth navigation and fail-closed AI',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      bool converted = false;
      Future<void> screenshot(String name) async {
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await tester.pumpAndSettle();
        final bytes = await binding.takeScreenshot(name);
        await File(
          '${Directory.systemTemp.path}/$name.png',
        ).writeAsBytes(bytes, flush: true);
      }

      Future<void> until(Finder finder) async {
        final watch = Stopwatch()..start();
        while (finder.evaluate().isEmpty &&
            watch.elapsed < const Duration(seconds: 90)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
      }

      await tester.pumpWidget(const SirajApp());
      await until(find.text('تخطي'));
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();
      await until(find.byKey(const Key('signup-username')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('signup-username')))
            .enabled,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const Key('signup-username')),
        'Synthetic Android Student',
      );
      await tester.enterText(
        find.byKey(const Key('signup-password')),
        'SIRAJ_native_test_only_2026!',
      );
      await tester.enterText(
        find.byKey(const Key('signup-confirmation')),
        'SIRAJ_native_test_only_2026!',
      );
      await tester.ensureVisible(find.byKey(const Key('signup-submit')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await until(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await screenshot('siraj-unified-home');
      await tester.ensureVisible(find.byKey(const Key('open-resource-status')));
      await tester.tap(find.byKey(const Key('open-resource-status')));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد موارد مسجلة في هذا القسم.'), findsWidgets);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المساعد التعليمي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-new-chat')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat-question-input')),
        'SYNTHETIC UI persistence check, no scientific answer expected',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send-enabled')));
      await until(find.byKey(const Key('chat-saved-question')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('موارد الذكاء الاصطناعي غير جاهزة'),
        findsOneWidget,
      );
      await screenshot('siraj-unified-chat-unavailable');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرئيسية').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      // Exercise the real account-scoped SQLite appearance writer on Android.
      await tester.tap(find.byKey(const Key('settings-theme-dark')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-language-en')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await screenshot('siraj-unified-settings-en-dark');
      await tester.tap(find.byKey(const Key('settings-language-ar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-theme-system')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('settings-logout')));
      await tester.tap(find.byKey(const Key('settings-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-account-action')));
      await until(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-username')),
        'Synthetic Android Student',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'SIRAJ_native_test_only_2026!',
      );
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await until(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-delete')),
        150,
      );
      await tester.ensureVisible(find.byKey(const Key('settings-delete')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-delete')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-delete')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-account-action')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('delete-account-checkbox')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-account-action')));
      await until(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      debugPrint(
        'SIRAJ_UNIFIED_ANDROID startup/signup/nativeKdf/keystore/sqlite/chat/logout/login/delete PASS; emulator only; AI unavailable; G2/G3 not run',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
