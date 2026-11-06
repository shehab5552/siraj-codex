import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/chat/chat_page.dart';
import 'package:siraj/features/chat/tutor_contracts.dart';

void main() {
  Future<void> render(WidgetTester tester, TutorResult result) =>
      tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: TutorResultView(result: result)),
          ),
        ),
      );
  testWidgets(
    'missing resources shows operational status with no fabricated answer',
    (tester) async {
      await render(tester, TutorResult.error(TutorReason.resourcesUnavailable));
      expect(find.textContaining('غير جاهزة'), findsOneWidget);
      expect(find.textContaining('المصدر:'), findsNothing);
    },
  );
  testWidgets('approved reference identities displayed without invented page', (
    tester,
  ) async {
    await render(
      tester,
      TutorResult.answer('test fixture text', [
        SourceReference(
          packId: 'fixture-pack',
          chunkId: 'fixture-chunk',
          datasetRevision: 'fixture-rev',
        ),
      ]),
    );
    expect(find.text('test fixture text'), findsOneWidget);
    expect(find.textContaining('fixture-pack / fixture-chunk'), findsOneWidget);
    expect(find.textContaining('صفحة'), findsNothing);
  });
  testWidgets(
    'partial is answer presentation and cancellation has no sources',
    (tester) async {
      await render(
        tester,
        TutorResult.answer('partial fixture', [
          SourceReference(packId: 'p', chunkId: 'c', datasetRevision: 'r'),
        ], isPartial: true),
      );
      expect(find.textContaining('إجابة جزئية'), findsOneWidget);
      await render(tester, TutorResult.error(TutorReason.cancelled));
      expect(find.textContaining('أُلغي'), findsOneWidget);
      expect(find.textContaining('المصدر:'), findsNothing);
    },
  );
}
