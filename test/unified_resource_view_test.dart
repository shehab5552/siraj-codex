import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/localization/siraj_copy.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/resource_repository.dart';
import 'package:siraj/features/resources/resource_status_reader.dart';
import 'package:siraj/features/resources/resource_status_page.dart';

void main() {
  testWidgets(
    'English resource view states missing approved catalog without fake download actions',
    (t) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            SirajCopyDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: ResourceStatusPage(
            reader: ResourceStatusReader(ResourceRepository(db)),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Resource status'), findsOneWidget);
      expect(find.text('Local model (LLM)'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const Key('resource-catalog-unavailable')),
        160,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('approved download catalog'), findsOneWidget);
      expect(find.text('Download'), findsNothing);
    },
  );
}
