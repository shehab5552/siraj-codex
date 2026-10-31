import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/library/pdf_reader_contracts.dart';
import 'package:siraj/features/library/pdf_reader_controller.dart';
import 'package:siraj/features/library/pdf_reader_page.dart';

class WidgetDocument implements PdfDocumentPort {
  @override
  String get id => 'widget-only';
  @override
  int get pageCount => 2;
  @override
  Future<PdfPageImage> render(int page, {required int width}) async =>
      throw const PdfFailure(PdfFailureCode.resourceLimit);
  @override
  Future<void> close() async {}
}

void main() {
  for (final rtl in [true, false]) {
    testWidgets(
      'PDF controls/error are bounded at 200% ${rtl ? 'RTL' : 'LTR'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PdfReaderController(WidgetDocument());
        await tester.pumpWidget(
          MaterialApp(
            theme: SirajTheme.light(),
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: PdfReaderPage(
                  controller: controller,
                  arabicTitle: 'مستند اختبار',
                  englishTitle: 'Test document',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pdf-next')), findsOneWidget);
        await tester.tap(find.byKey(const Key('pdf-next')));
        await tester.pumpAndSettle();
        expect(controller.page, 1);
        expect(tester.takeException(), isNull);
        await controller.close();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
