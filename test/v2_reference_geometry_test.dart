import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/home/home_page.dart';
import 'package:siraj/features/onboarding/onboarding_page.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansArabic',
    )..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'))).load();
  });
  testWidgets(
    'measured HTML geometry: 68 toolbar, 350x233.8 hero and 227 illustration',
    (t) async {
      t.view.physicalSize = const Size(380, 737);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: SirajTheme.light(),
          home: HomePage(
            onOpenChat: () {},
            onOpenResources: () {},
            onOpenHistory: () {},
            onOpenSettings: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final hero = t.getRect(find.byKey(const Key('v2-home-hero')));
      expect(hero.left, 15);
      expect(hero.top, 85);
      expect(hero.width, 350);
      expect(hero.height, closeTo(233.8, 1));
      await t.pumpWidget(
        MaterialApp(
          theme: SirajTheme.light(),
          home: OnboardingPage(onComplete: () async => true),
        ),
      );
      await t.pumpAndSettle();
      final illustration = t.getRect(
        find.byKey(const Key('v2-onboarding-illustration')),
      );
      expect(illustration, const Rect.fromLTWH(15, 112, 350, 227));
      expect(
        t.getRect(find.byKey(const Key('v2-illustration-halo'))),
        const Rect.fromLTWH(89, 124.5, 202, 202),
      );
      expect(
        t.getRect(find.byKey(const Key('v2-illustration-bookicon'))),
        const Rect.fromLTWH(139, 174, 102, 103),
      );
      expect(
        t.getTopLeft(find.byKey(const Key('onboarding-next'))).dy,
        closeTo(512, 1),
      );
    },
  );
  testWidgets('home uses reference hero copy and 15px content gutters', (
    t,
  ) async {
    t.view.physicalSize = const Size(380, 737);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
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
    expect(find.text('كل سؤال يقربك\nمن الفهم'), findsOneWidget);
    expect(t.getSize(find.byKey(const Key('v2-home-hero'))).width, 350);
    expect(t.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    test('V2 measured geometry and typography dark=$dark', () {
      final theme = dark ? SirajTheme.dark() : SirajTheme.light();
      expect(theme.appBarTheme.toolbarHeight, 68);
      expect(theme.navigationBarTheme.height, 66);
      expect(theme.cardTheme.margin, EdgeInsets.zero);
      expect(theme.textTheme.bodyMedium!.fontSize, 13);
      expect(theme.textTheme.titleMedium!.fontSize, 12);
      expect(theme.textTheme.labelLarge!.fontSize, 11);
      expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
      final border =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(12));
    });
  }
}
