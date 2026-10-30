import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/core/localization/siraj_copy.dart';
import 'package:siraj/features/home/siraj_main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final sample in [
    ('ar', false, const Size(390, 844)),
    ('en', true, const Size(1024, 768)),
  ]) {
    testWidgets(
      'V2 home ${sample.$1} ${sample.$2 ? "dark tablet" : "light phone"}',
      (t) async {
        t.view.physicalSize = sample.$3;
        t.view.devicePixelRatio = 1;
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
        });
        await t.pumpWidget(
          RepaintBoundary(
            key: const Key('golden'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: Locale(sample.$1),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                SirajCopyDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: sample.$2 ? SirajTheme.dark() : SirajTheme.light(),
              home: SirajMainShell(
                onOpenChat: () {},
                onOpenResources: () {},
                onOpenHistory: () {},
                onOpenQuiz: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final semantics = t.ensureSemantics();
        try {
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
        await expectLater(
          find.byKey(const Key('golden')),
          matchesGoldenFile(
            'goldens/v2_home_${sample.$1}_${sample.$2 ? "dark" : "light"}.png',
          ),
        );
      },
    );
  }
}
