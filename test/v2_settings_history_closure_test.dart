import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_preferences.dart';
import 'package:siraj/app/app_session_controller.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';
import 'package:siraj/features/settings/settings_page.dart';
import 'package:siraj/features/chat/conversation_history_controller.dart';
import 'package:siraj/features/chat/conversation_history_page.dart';
import 'support/auth_test_marker.dart';
import 'support/chat_fixture.dart';

class DeviceStore implements AppPreferencesStore {
  @override
  Future<AppPreferences> read() async => const AppPreferences();
  @override
  Future<void> write(AppPreferences next) async {}
}

void main() {
  testWidgets(
    'settings uses compact reference rows and real light dark system selection',
    (t) async {
      final runtime = DatabaseRuntime(
        createDatabase: () => AppDatabase.forTesting(NativeDatabase.memory()),
      );
      final session = AppSessionController(
        runtime: runtime,
        markerStore: ControlledMarker(),
      );
      final prefs = AppPreferencesController(DeviceStore());
      await prefs.ready;
      try {
        await t.pumpWidget(
          AppPreferencesScope(
            controller: prefs,
            child: MaterialApp(
              theme: SirajTheme.light(),
              home: SettingsPage(session: session, onOpenResources: () {}),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('مظهر التطبيق'), findsOneWidget);
        expect(find.byType(DropdownButton<ThemeMode>), findsNothing);
        await t.tap(find.byKey(const Key('settings-theme-dark')));
        await t.pumpAndSettle();
        expect(prefs.value.themeMode, ThemeMode.dark);
        await t.tap(find.byKey(const Key('settings-theme-system')));
        await t.pumpAndSettle();
        expect(prefs.value.themeMode, ThemeMode.system);
        expect(
          t.getSize(find.byKey(const Key('v2-settings-appearance-row'))).height,
          59,
        );
      } finally {
        await t.pumpWidget(const SizedBox());
        prefs.dispose();
        session.dispose();
        await runtime.close();
      }
    },
  );
  testWidgets(
    'history displays actual count and places New Chat after cards and retention note',
    (t) async {
      final f = ChatFixture();
      await f.initialize();
      await f.conversations.saveFirstUserMessage(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: 'visual-history',
        messageId: 'visual-user',
        question: 'سؤال اصطناعي للاختبار',
        nowUtc: ChatFixture.stamp,
        sessionNonceHash: f.nonceHash,
      );
      final history = ConversationHistoryController(
        session: f.session,
        conversations: f.conversations,
        guard: f.guard,
      );
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: SirajTheme.light(),
            home: ConversationHistoryPage(controller: history),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('1 من 10'), findsOneWidget);
        expect(
          t.getTopLeft(find.byKey(const Key('history-new-chat'))).dy,
          greaterThan(
            t.getBottomLeft(find.byKey(const Key('history-visual-history'))).dy,
          ),
        );
        expect(find.byKey(const Key('v2-history-retention')), findsOneWidget);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await f.close();
      }
    },
  );
}
