import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'package:siraj/integrations/ai/tutor_pipeline_contract.dart';
import 'support/b09_pipeline_fixture.dart';
import 'support/chat_fixture.dart';

void main() {
  late ChatFixture db;
  late PipelineFixture ai;
  late ChatTurnCoordinator chat;
  var serial = 0;
  setUp(() async {
    serial = 0;
    db = ChatFixture();
    await db.initialize();
    ai = PipelineFixture();
    chat = ChatTurnCoordinator(
      session: db.session,
      conversations: db.conversations,
      guard: db.guard,
      tutor: ai.pipeline,
      sources: ai.pipeline,
      newId: () => 'b09-${serial++}',
    );
    await chat.initialize();
  });
  tearDown(() async {
    chat.dispose();
    await ai.pipeline.close();
    await db.close();
  });
  Future<List<String>> roles() async => (await db.conversations.listMessages(
    userId: db.session.userId,
    accountEpoch: db.session.accountEpoch,
    conversationId: chat.conversationId!,
    sessionNonceHash: db.nonceHash,
  )).map((r) => r.read<String>('role')).toList();
  Future<void> generationStarted() async {
    for (var i = 0; i < 200 && ai.runtime.calls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(ai.runtime.calls, 1);
  }

  test(
    'USER commits before pipeline generation and follow-up uses same saved chat',
    () async {
      ai.runtime.paused = Completer<String>();
      final sending = chat.send('synthetic first question');
      await generationStarted();
      expect(await roles(), ['USER']);
      final id = chat.conversationId;
      ai.runtime.paused!.complete('SYNTHETIC TEST ANSWER');
      await sending;
      expect(await roles(), ['USER', 'ASSISTANT']);
      ai.runtime.paused = null;
      await chat.send('synthetic follow-up');
      expect(chat.conversationId, id);
      expect(await roles(), ['USER', 'ASSISTANT', 'USER', 'ASSISTANT']);
      expect(ai.datasets.handle.embedder.calls, 2);
    },
  );
  test(
    'runtime error retains committed USER without counterfeit assistant',
    () async {
      ai.evidence.assessment = EvidenceAssessment(
        decision: EvidenceDecision.full,
      );
      await chat.send('synthetic question');
      expect(await roles(), ['USER']);
      expect(chat.failure, isNotNull);
    },
  );
  test(
    'cancel while generating prevents late pipeline result from reaching SQLite',
    () async {
      ai.runtime.paused = Completer<String>();
      final sending = chat.send('synthetic question');
      await generationStarted();
      await chat.cancel();
      expect(await roles(), ['USER']);
      expect(ai.datasets.handle.closed, 0);
      ai.runtime.paused!.complete('LATE TEST OUTPUT');
      await sending;
      await ai.pipeline.whenIdle;
      expect(await roles(), ['USER']);
      expect(ai.datasets.handle.closed, 1);
    },
  );
  test('logout during generation prevents old request persistence', () async {
    ai.runtime.paused = Completer<String>();
    final sending = chat.send('synthetic question');
    await generationStarted();
    await db.logout();
    ai.runtime.paused!.complete('LATE TEST OUTPUT');
    await sending;
    await ai.pipeline.whenIdle;
    final rows = await db.db.customSelect("SELECT role FROM message").get();
    expect(rows.map((r) => r.read<String>('role')), ['USER']);
    expect(chat.phase, ChatPhase.sessionExpired);
  });
  test(
    'delete during generation cascades USER and forbids late assistant',
    () async {
      ai.runtime.paused = Completer<String>();
      final sending = chat.send('synthetic question');
      await generationStarted();
      await db.users.deleteAccount(
        userId: db.session.userId,
        accountEpoch: db.session.accountEpoch,
      );
      ai.runtime.paused!.complete('LATE TEST OUTPUT');
      await sending;
      await ai.pipeline.whenIdle;
      expect(await db.db.customSelect('SELECT * FROM message').get(), isEmpty);
      expect(
        await db.db.customSelect('SELECT * FROM conversation').get(),
        isEmpty,
      );
    },
  );
}
