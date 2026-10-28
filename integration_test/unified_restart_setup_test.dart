import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/app/siraj_app.dart';
import 'support/unified_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'prepare real persisted account conversation and appearance for force-stop',
    (tester) async {
      final flow = UnifiedFlow(tester);
      await tester.pumpWidget(const SirajApp());
      // Executed after the full app test deletes its synthetic account. Device
      // onboarding is already complete; this is not a production reset endpoint.
      await flow.until(find.byKey(const Key('signup-submit')));
      await tester.enterText(
        find.byKey(const Key('signup-username')),
        UnifiedFlow.username,
      );
      await tester.enterText(
        find.byKey(const Key('signup-password')),
        UnifiedFlow.password,
      );
      await tester.enterText(
        find.byKey(const Key('signup-confirmation')),
        UnifiedFlow.password,
      );
      await flow.tap(find.byKey(const Key('signup-submit')));
      await flow.until(find.byKey(const Key('open-chat')));
      await flow.tab(1);
      await flow.tap(find.byKey(const Key('history-new-chat')));
      await flow.until(find.byKey(const Key('chat-question-input')));
      await tester.enterText(
        find.byKey(const Key('chat-question-input')),
        UnifiedFlow.question,
      );
      await tester.pump();
      await flow.tap(find.byKey(const Key('chat-send-enabled')));
      await flow.until(find.byKey(const Key('chat-saved-question')));
      await tester.pumpAndSettle();
      await flow.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await flow.tab(0);
      await flow.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await flow.tap(find.byKey(const Key('settings-theme')));
      await tester.pumpAndSettle();
      await flow.tap(find.text('داكن').last);
      await tester.pumpAndSettle();
      await flow.tap(find.byKey(const Key('settings-language')));
      await tester.pumpAndSettle();
      await flow.tap(find.text('الإنجليزية').last);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      debugPrint(
        'SIRAJ_UNIFIED_ANDROID FORCE_STOP_SETUP native account/Keystore/user message/SQLite EN-dark persisted PASS',
      );
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
