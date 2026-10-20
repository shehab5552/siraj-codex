import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/siraj_app.dart';

void main() {
  testWidgets('Debug preview opens with SIRAJ branding', (tester) async {
    await tester.pumpWidget(const SirajApp());

    expect(find.text('سراج'), findsOneWidget);
    expect(find.byKey(const Key('open-chat')), findsOneWidget);
  });

  testWidgets('Chat preview does not allow sending messages', (tester) async {
    await tester.pumpWidget(const SirajApp());
    await tester.tap(find.byKey(const Key('open-chat')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-question-input')), findsOneWidget);
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('chat-send-disabled')),
    );
    expect(sendButton.onPressed, isNull);
  });
}
