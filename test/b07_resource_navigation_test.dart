import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/resource_repository.dart';
import 'package:siraj/features/home/home_page.dart';
import 'package:siraj/features/resources/resource_status_page.dart';
import 'package:siraj/features/resources/resource_status_reader.dart';

void main() {
  testWidgets('B-07 preview never offers a resource navigation action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.byKey(const Key('open-resource-status')), findsNothing);
  });

  testWidgets(
    'B-07 authenticated home exposes resource action only with handler',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: HomePage(onOpenChat: () {})));
      expect(find.byKey(const Key('open-resource-status')), findsNothing);

      var visits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(onOpenChat: () {}, onOpenResources: () => visits++),
        ),
      );
      expect(find.byKey(const Key('open-resource-status')), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-resource-status')));
      expect(visits, 1);
    },
  );

  testWidgets('B-07 resource navigation opens read-only registry', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final reader = ResourceStatusReader(ResourceRepository(db));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => HomePage(
            onOpenChat: () {},
            onOpenResources: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ResourceStatusPage(reader: reader),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-resource-status')));
    await tester.pumpAndSettle();
    expect(find.text('حالة الموارد'), findsOneWidget);
    expect(find.text('النموذج المحلي (LLM)'), findsOneWidget);
    expect(find.text('لا توجد موارد مسجلة في هذا القسم.'), findsWidgets);
    expect(find.text('تنزيل'), findsNothing);
  });
}
