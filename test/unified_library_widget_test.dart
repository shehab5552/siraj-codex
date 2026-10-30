import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/library/library_contracts.dart';
import 'package:siraj/features/library/library_controller.dart';
import 'package:siraj/features/library/library_page.dart';
import 'unified_library_controller_test.dart' show testBook;

class _Catalog implements ApprovedLibraryCatalog {
  @override
  Future<List<LibraryBook>?> read() async => [
    testBook('alpha', 'a'),
    testBook('beta', 'b'),
  ];
}

void main() {
  testWidgets(
    'library searches actual supplied metadata and never offers unverified open',
    (t) async {
      final c = LibraryController(catalog: _Catalog());
      await t.pumpWidget(
        MaterialApp(
          home: LibraryPage(controller: c, onOpenResources: () {}),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('كتاب اصطناعي alpha'), findsOneWidget);
      await t.enterText(find.byKey(const Key('library-search')), 'beta');
      await t.pumpAndSettle();
      expect(find.text('كتاب اصطناعي alpha'), findsNothing);
      expect(find.text('كتاب اصطناعي beta'), findsOneWidget);
      expect(find.byKey(const Key('library-open-beta')), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
