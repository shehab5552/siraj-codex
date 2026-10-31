import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/siraj_app.dart';
import 'package:siraj/core/design/siraj_v2_components.dart';

void main() {
  testWidgets('Explicit debug preview opens with SIRAJ branding', (
    tester,
  ) async {
    await tester.pumpWidget(const SirajApp(debugPreview: true));
    expect(find.byType(SirajBrandMark), findsOneWidget);
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.byKey(const Key('open-chat')), findsOneWidget);
  });

  testWidgets('Debug chat preview cannot send messages', (tester) async {
    await tester.pumpWidget(const SirajApp(debugPreview: true));
    await tester.tap(find.byKey(const Key('open-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-question-input')), findsOneWidget);
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('chat-send-disabled')),
    );
    expect(sendButton.onPressed, isNull);
  });
}
