import 'package:siraj/features/chat/chat_page.dart';
import 'support/native_results.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/app/siraj_app.dart';
import 'support/unified_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  recordNativeResults(binding, 'restart-restore', 1);
  testWidgets(
    'restore actual session conversation and appearance after adb force-stop',
    (tester) async {
      final flow = UnifiedFlow(tester);
      await tester.pumpWidget(const SirajApp());
      await flow.until(find.byKey(const Key('open-chat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-submit')), findsNothing);
      final context = tester.element(find.byKey(const Key('open-chat')));
      expect(Directionality.of(context), TextDirection.ltr);
      expect(Theme.of(context).brightness, Brightness.dark);
      await flow.tab(1);
      await flow.until(find.text(UnifiedFlow.question));
      await flow.tap(find.text(UnifiedFlow.question));
      await flow.until(find.byKey(const Key('chat-saved-question')));
      final displayedQuestion = find.descendant(
        of: find.byKey(const Key('chat-message-list')),
        matching: find.text(UnifiedFlow.question),
      );
      await tester.pumpAndSettle();
      expect(displayedQuestion, findsOneWidget);
      final chat = tester.widget<ChatPage>(find.byType(ChatPage)).coordinator!;
      final savedUsers = chat.messages.where((m) => m.isUser).toList();
      expect(savedUsers, hasLength(1));
      final persistedUserId = savedUsers.single.id;
      // Operational Tutor errors are not persisted. A reopened unanswered USER
      // is reconstructed as retryable, then retry must reuse that same USER.
      expect(find.byKey(const Key('chat-no-ai-answer')), findsOneWidget);
      expect(
        find.textContaining('Your last question is saved without an answer'),
        findsOneWidget,
      );
      await flow.tap(find.byKey(const Key('chat-retry')));
      await flow.until(find.textContaining('AI resources are not ready'));
      expect(displayedQuestion, findsOneWidget);
      expect(chat.messages.where((m) => m.isUser), hasLength(1));
      expect(chat.messages.singleWhere((m) => m.isUser).id, persistedUserId);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final png = await binding.takeScreenshot('siraj-force-stop-restored');
      await File(
        '${Directory.systemTemp.path}/siraj-force-stop-restored.png',
      ).writeAsBytes(png, flush: true);
      await flow.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await flow.tab(0);
      await flow.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await flow.tap(find.byKey(const Key('settings-logout')));
      await tester.pumpAndSettle();
      await flow.tap(find.byKey(const Key('confirm-account-action')));
      await flow.until(find.byKey(const Key('login-submit')));
      await tester.enterText(
        find.byKey(const Key('login-username')),
        UnifiedFlow.username,
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        UnifiedFlow.password,
      );
      await flow.tap(find.byKey(const Key('login-submit')));
      await flow.until(find.byKey(const Key('open-settings')));
      await flow.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-delete')),
        150,
      );
      await flow.tap(find.byKey(const Key('settings-delete')));
      await tester.pumpAndSettle();
      await flow.tap(find.byKey(const Key('delete-account-checkbox')));
      await tester.pumpAndSettle();
      await flow.tap(find.byKey(const Key('confirm-account-action')));
      await flow.until(find.byKey(const Key('signup-submit')));
      debugPrint(
        'SIRAJ_UNIFIED_ANDROID FORCE_STOP_RESTORE real Keystore session/SQLite conversation/EN-dark/logout/login/delete PASS; emulator only',
      );
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
