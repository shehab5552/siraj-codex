import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/app/app_routes.dart';
import 'package:siraj/features/chat/chat_page.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'package:siraj/features/chat/conversation_history_controller.dart';
import 'package:siraj/features/chat/conversation_history_page.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';
import 'package:siraj/features/home/home_page.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';

import 'support/chat_fixture.dart';
import 'support/chat_widget_harness.dart';
import 'support/fake_tutor.dart';

void main() {
  late ChatFixture f;
  late FakeTutor tutor;
  late FakeSourceResolver sources;
  final opened = <ChatTurnCoordinator>[];
  final histories = <ConversationHistoryController>[];
  setUp(() async {
    f = ChatFixture();
    await f.initialize();
    tutor = FakeTutor();
    sources = FakeSourceResolver();
  });
  tearDown(() async {
    for (final c in opened) {
      c.dispose();
    }
    opened.clear();
    for (final h in histories) {
      h.dispose();
    }
    histories.clear();
    await f.close();
  });
  ChatTurnCoordinator create({bool unavailable = false}) {
    final c = ChatTurnCoordinator(
      session: f.session,
      conversations: f.conversations,
      guard: f.guard,
      tutor: unavailable ? const UnavailableTutorPort() : tutor,
      sources: sources,
    );
    opened.add(c);
    return c;
  }

  Future<void> render(WidgetTester t, ChatTurnCoordinator c) async {
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF254A65)),
          useMaterial3: true,
        ),
        home: ChatPage(coordinator: c),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> send(WidgetTester t, String text, {bool settle = true}) async {
    await t.enterText(find.byKey(const Key('chat-question-input')), text);
    await t.pump();
    await t.tap(find.byKey(const Key('chat-send-enabled')));
    if (settle) {
      await t.pumpAndSettle();
    } else {
      for (var i = 0; i < 30 && tutor.requests.isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 10));
      }
    }
  }

  Future<void> seedTenConversations() async {
    for (var i = 0; i < 10; i++) {
      await f.conversations.saveFirstUserMessage(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: 'old-$i',
        messageId: 'old-user-$i',
        question: 'old question $i',
        nowUtc: ChatFixture.stamp,
        sessionNonceHash: f.nonceHash,
      );
    }
  }

  chatWidgetTest('reopened unanswered USER exposes retry without duplication', (
    t,
  ) async {
    final first = create(unavailable: true);
    await first.initialize();
    await first.send('السؤال المحفوظ');
    final reopened = ChatTurnCoordinator(
      session: f.session,
      conversations: f.conversations,
      guard: f.guard,
      tutor: tutor,
      conversationId: first.conversationId,
    );
    opened.add(reopened);
    await render(t, reopened);
    expect(find.byKey(const Key('chat-retry')), findsOneWidget);
    await t.tap(find.byKey(const Key('chat-retry')));
    await t.pumpAndSettle();
    expect(reopened.messages.map((m) => m.isUser), [true, false]);
    expect(tutor.requests, hasLength(1));
  });

  chatWidgetTest(
    'eleventh first send shows nonblocking eviction notice only once',
    (t) async {
      await seedTenConversations();
      final c = create(unavailable: true);
      await render(t, c);
      expect(find.byType(SnackBar), findsNothing);
      await send(t, 'المحادثة الحادية عشرة');
      expect(
        find.text('حُذفت أقدم محادثة بعد حفظ سؤالك؛ يُحفظ آخر عشر محادثات.'),
        findsOneWidget,
      );
      expect(
        await f.conversations.listConversations(
          userId: f.session.userId,
          accountEpoch: f.session.accountEpoch,
        ),
        hasLength(10),
      );
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('chat-retry')));
      await t.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  chatWidgetTest(
    'failed first transaction keeps oldest chat and emits no eviction notice',
    (t) async {
      await seedTenConversations();
      await f.db.customStatement(
        "CREATE TRIGGER fail_first BEFORE INSERT ON message BEGIN SELECT RAISE(ABORT, 'isolated rollback'); END;",
      );
      final c = create(unavailable: true);
      await render(t, c);
      await send(t, 'rollback');
      expect(find.byType(SnackBar), findsNothing);
      final rows = await f.conversations.listConversations(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
      );
      expect(rows, hasLength(10));
      expect(
        rows.map((r) => r.read<String>('conversation_id')),
        contains('old-0'),
      );
    },
  );

  chatWidgetTest(
    'RTL chat saves USER and shows unavailability without fake answer',
    (t) async {
      final c = create(unavailable: true);
      await render(t, c);
      expect(
        Directionality.of(
          t.element(find.byKey(const Key('chat-question-input'))),
        ),
        TextDirection.rtl,
      );
      await send(t, 'سؤال محفوظ');
      expect(find.text('سؤال محفوظ'), findsOneWidget);
      expect(find.byKey(const Key('chat-no-ai-answer')), findsOneWidget);
      expect(find.byKey(const Key('chat-retry')), findsOneWidget);
      expect(c.messages, hasLength(1));
      expect(c.messages.single.isUser, true);
    },
  );
  chatWidgetTest(
    'answer sources open verified snippet without an invented page',
    (t) async {
      final c = create();
      await render(t, c);
      await send(t, 'سؤال');
      expect(find.text('إجابة اختبار اصطناعية'), findsOneWidget);
      await t.tap(find.byKey(const Key('chat-source-0-0')));
      await t.pumpAndSettle();
      expect(find.text('مقتطف اختبار اصطناعي'), findsOneWidget);
      expect(find.textContaining('صفحة'), findsNothing);
    },
  );
  chatWidgetTest(
    'partial, refusal and runtime error have distinct presentation',
    (t) async {
      final c = create();
      await render(t, c);
      tutor.respond = (r) => replyFor(
        r,
        result: TutorResult.answer('جزء مدعوم', [testSource], partial: true),
      );
      await send(t, 'أول');
      expect(find.byKey(const Key('chat-partial')), findsOneWidget);
      tutor.respond = (r) => replyFor(
        r,
        result: TutorResult.refusal(TutorReason.needsScopeClarification),
      );
      await send(t, 'ثان');
      expect(find.textContaining('أحتاج توضيح'), findsOneWidget);
      tutor.respond = (r) => replyFor(
        r,
        result: TutorResult.error(TutorErrorCode.modelLoadFailed),
      );
      await send(t, 'ثالث');
      expect(find.textContaining('تحميل النموذج'), findsOneWidget);
      expect(c.messages.where((m) => !m.isUser), hasLength(2));
    },
  );
  chatWidgetTest('loading can be cancelled and late answer never appears', (
    t,
  ) async {
    final response = Completer<TutorReply>();
    tutor.respond = (_) => response.future;
    final c = create();
    await render(t, c);
    await send(t, 'سؤال جارٍ', settle: false);
    expect(find.byKey(const Key('chat-loading')), findsOneWidget);
    await t.tap(find.byKey(const Key('chat-cancel')));
    await t.pumpAndSettle();
    response.complete(replyFor(tutor.requests.single));
    await t.pumpAndSettle();
    expect(find.text('إجابة اختبار اصطناعية'), findsNothing);
    expect(find.text('سؤال جارٍ'), findsOneWidget);
    expect(c.isBusy, false);
  });
  chatWidgetTest(
    'Logout hides an open source panel and rejects its late content',
    (t) async {
      final c = create();
      await render(t, c);
      await send(t, 'سؤال خاص');
      final resolution = Completer<ResolvedSource?>();
      sources.respond = (_) => resolution.future;
      await t.tap(find.byKey(const Key('chat-source-0-0')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await f.logout();
      await t.pumpAndSettle();
      resolution.complete(
        const ResolvedSource(
          reference: testSource,
          snippet: 'late private snippet',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('late private snippet'), findsNothing);
      expect(c.messages, isEmpty);
    },
  );
  chatWidgetTest('history opens saved messages and accepts follow-up', (
    t,
  ) async {
    final c = create();
    await c.initialize();
    await c.send('عنوان المحادثة');
    final history = ConversationHistoryController(
      session: f.session,
      conversations: f.conversations,
      guard: f.guard,
      tutor: tutor,
      sources: sources,
    );
    histories.add(history);
    await t.pumpWidget(
      MaterialApp(home: ConversationHistoryPage(controller: history)),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('يُحذف الأقدم تلقائيًا'), findsOneWidget);
    await t.tap(find.text('عنوان المحادثة'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chat-question-input')), findsOneWidget);
    await send(t, 'سؤال متابعة');
    expect(find.text('سؤال متابعة'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('عنوان المحادثة'), findsOneWidget);
  });
  chatWidgetTest('narrow RTL layout supports large text without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = create(unavailable: true);
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.8),
          ),
          child: ChatPage(coordinator: c),
        ),
      ),
    );
    await t.pumpAndSettle();
    await send(t, 'سؤال طويل للاختبار على شاشة صغيرة');
    expect(t.takeException(), isNull);
  });

  chatWidgetTest('authenticated named route injects Tutor without UI changes', (
    t,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final draft = ConversationDraftController(
      conversations: f.conversations,
      guard: f.guard,
    );
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: Scaffold(
          body: TextButton(
            onPressed: () => navigator.currentState!.pushNamed(
              AppRoutes.chat,
              arguments: AuthenticatedChatRoute(
                session: f.session,
                draftController: draft,
                tutor: tutor,
                sources: sources,
              ),
            ),
            child: const Text('افتح'),
          ),
        ),
      ),
    );
    await t.tap(find.text('افتح'));
    await t.pumpAndSettle();
    await send(t, 'question');
    expect(find.text('إجابة اختبار اصطناعية'), findsOneWidget);
  });
  chatWidgetTest('authenticated home exposes conversation history entry', (
    t,
  ) async {
    var opened = false;
    await t.pumpWidget(
      MaterialApp(
        home: HomePage(onOpenChat: () {}, onOpenHistory: () => opened = true),
      ),
    );
    await t.scrollUntilVisible(find.byKey(const Key('open-chat-history')), 180);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('open-chat-history')));
    expect(opened, true);
  });
  chatWidgetTest('Logout removes the pending private composer text', (t) async {
    final response = Completer<TutorReply>();
    tutor.respond = (_) => response.future;
    final c = create();
    await render(t, c);
    await send(t, 'سؤال خاص جارٍ', settle: false);
    await f.logout();
    await t.pumpAndSettle();
    final input = t.widget<TextField>(
      find.byKey(const Key('chat-question-input')),
    );
    expect(input.controller!.text, isEmpty);
    expect(input.enabled, false);
    response.complete(replyFor(tutor.requests.single));
    await t.pumpAndSettle();
  });
}
