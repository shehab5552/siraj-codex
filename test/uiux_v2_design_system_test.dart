import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/home/siraj_main_shell.dart';

void main() {
  test('V2 has distinct light and dark themes', () {
    expect(SirajTheme.light().brightness, Brightness.light);
    expect(SirajTheme.dark().brightness, Brightness.dark);
    expect(SirajTheme.light().colorScheme.primary, isNot(SirajTheme.dark().colorScheme.primary));
  });

  testWidgets('V2 bottom navigation selects exactly one page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: SirajTheme.light(),
      home: const Directionality(textDirection: TextDirection.rtl, child: SirajMainShell()),
    ));
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 0);
    await tester.tap(find.text('المكتبة').last);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    expect(find.text('قائمة الكتب وتنزيل ملفات PDF المعتمدة غير موصولين في هذا الفرع بعد.'), findsOneWidget);
    await tester.tap(find.text('الاختبارات').last);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
    expect(find.textContaining('لا توجد أسئلة جاهزة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
