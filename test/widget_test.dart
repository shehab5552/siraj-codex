import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/siraj_app.dart';

void main() {
  testWidgets('Explicit debug preview opens with SIRAJ branding', (
    tester,
  ) async {
    await tester.pumpWidget(const SirajApp(debugPreview: true));
    expect(find.text('سراج'), findsOneWidget);
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
