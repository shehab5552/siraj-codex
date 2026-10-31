import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/onboarding/onboarding_page.dart';
import 'package:siraj/features/home/home_page.dart';

void main() {
  testWidgets(
    'onboarding follows approved four-slide copy and bottom action order',
    (t) async {
      t.view.physicalSize = const Size(380, 737);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var completed = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: SirajTheme.light(),
          home: OnboardingPage(
            onComplete: () async {
              completed++;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('معك خطوة بخطوة'), findsOneWidget);
      expect(find.text('تعلم أينما كنت'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('تخطي')).dy,
        greaterThan(
          t.getBottomLeft(find.byKey(const Key('onboarding-next'))).dy,
        ),
      );
      for (final title in ['اسأل وتعلّم', 'مكتبتك في هاتفك', 'اختبر فهمك']) {
        await t.ensureVisible(find.byKey(const Key('onboarding-next')));
        await t.tap(find.byKey(const Key('onboarding-next')));
        await t.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
      }
      expect(completed, 0);
      await t.ensureVisible(find.byKey(const Key('onboarding-next')));
      await t.tap(find.byKey(const Key('onboarding-next')));
      await t.pumpAndSettle();
      expect(completed, 1);
    },
  );
  testWidgets('home uses the reference page title and ask action', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: SirajTheme.light(),
        home: HomePage(
          onOpenChat: () {},
          onOpenResources: () {},
          onOpenSettings: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('الرئيسية')),
      findsOneWidget,
    );
    expect(find.text('اسأل سراج'), findsOneWidget);
  });
}
