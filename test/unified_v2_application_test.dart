import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/app/siraj_app.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/onboarding/onboarding_page.dart';

class _Store implements AppPreferencesStore {
  AppPreferences value = const AppPreferences();
  @override
  Future<AppPreferences> read() async => value;
  @override
  Future<void> write(AppPreferences next) async {
    value = next;
  }
}

void main() {
  testWidgets('app changes locale, direction and persisted theme together', (
    tester,
  ) async {
    final prefs = AppPreferencesController(_Store());
    await prefs.ready;
    await tester.pumpWidget(SirajApp(debugPreview: true, preferences: prefs));
    await tester.pumpAndSettle();
    await prefs.setLocale(const Locale('en'));
    await prefs.setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    final homeContext = tester.element(find.byKey(const Key('open-chat')));
    expect(Directionality.of(homeContext), TextDirection.ltr);
    expect(find.text('Welcome to a world of learning'), findsOneWidget);
    await prefs.setTheme(ThemeMode.system);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    await tester.pumpWidget(const SizedBox());
    prefs.dispose();
  });
  testWidgets(
    'onboarding scrolls at large text and only persists after completion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: OnboardingPage(
              onComplete: () async {
                finished++;
                return true;
              },
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('onboarding-next')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await tester.pumpAndSettle();
      }
      expect(finished, 0);
      await tester.scrollUntilVisible(
        find.byKey(const Key('onboarding-next')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(tester.takeException(), isNull);
    },
  );
  test('V2 surface app bar and readable semantic tokens', () {
    final theme = SirajTheme.light();
    expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
    expect(theme.extension<SirajSemanticColors>(), isNotNull);
  });
}
