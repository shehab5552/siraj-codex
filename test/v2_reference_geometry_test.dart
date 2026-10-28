import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/home/home_page.dart';

void main() {
  testWidgets('home uses reference hero copy and 15px content gutters', (t) async {
    t.view.physicalSize = const Size(380, 737);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(theme: SirajTheme.light(), home: HomePage(onOpenChat: () {}, onOpenResources: () {}, onOpenSettings: () {})));
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
