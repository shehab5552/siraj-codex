import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';

import 'support/chat_fixture.dart';
import 'support/fake_tutor.dart';

class PausedChatRead extends ConversationRepository {
  PausedChatRead(super.db);
  bool paused = false;
  final waiting = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<QueryRow>> listMessages({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    Uint8List? sessionNonceHash,
  }) async {
    if (paused) {
      if (!waiting.isCompleted) waiting.complete();
      await release.future;
    }
    return super.listMessages(
      userId: userId,
      accountEpoch: accountEpoch,
      conversationId: conversationId,
      sessionNonceHash: sessionNonceHash,
    );
  }
}

class PausedChatWrite extends ConversationRepository {
  PausedChatWrite(super.db);
  final waiting = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> appendAssistantMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String answer,
    required String sourceRefsJson,
    required String nowUtc,
    Uint8List? sessionNonceHash,
    bool Function()? isRequestCurrent,
    String? inReplyToMessageId,
  }) async {
    if (!waiting.isCompleted) waiting.complete();
    await release.future;
    return super.appendAssistantMessage(
      userId: userId,
      accountEpoch: accountEpoch,
      conversationId: conversationId,
      messageId: messageId,
      answer: answer,
      sourceRefsJson: sourceRefsJson,
      nowUtc: nowUtc,
      sessionNonceHash: sessionNonceHash,
      isRequestCurrent: isRequestCurrent,
      inReplyToMessageId: inReplyToMessageId,
    );
  }
}

void main() {
  late ChatFixture f;
  late FakeTutor tutor;
  late FakeSourceResolver resolver;
  final coordinators = <ChatTurnCoordinator>[];
  var serial = 0;
  var fixtureOpen = true;
  ChatTurnCoordinator create({String? id, TutorPort? port}) {
    final c = ChatTurnCoordinator(
      session: f.session,
      conversations: f.conversations,
      guard: f.guard,
      tutor: port ?? tutor,
      sources: resolver,
      conversationId: id,
      newId: () => 'turn-${serial++}',
      clock: () => DateTime.utc(2026, 10, 22, 12, 0, serial),
    );
    coordinators.add(c);
    return c;
  }

  Future<List<String>> roles(ChatTurnCoordinator c) async =>
      (await f.conversations.listMessages(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: c.conversationId!,
      )).map((r) => r.read<String>('role')).toList();

  setUp(() async {
    fixtureOpen = true;
    serial = 0;
    f = ChatFixture();
    await f.initialize();
    tutor = FakeTutor();
    resolver = FakeSourceResolver();
  });
  tearDown(() async {
    for (final c in coordinators) {
      c.dispose();
    }
    coordinators.clear();
    if (fixtureOpen) await f.close();
  });

  test('opening draft never creates a conversation', () async {
    final c = create();
    await c.initialize();
    expect(c.phase, ChatPhase.ready);
    expect(c.messages, isEmpty);
    expect(
      await f.conversations.listConversations(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
      ),
      isEmpty,
    );
  });
  test('lifecycle refresh cannot stop a saved turn before Tutor', () async {
    final repo = PausedChatRead(f.db);
    final c = ChatTurnCoordinator(
      session: f.session,
      conversations: repo,
      guard: f.guard,
      tutor: tutor,
    );
    coordinators.add(c);
    await c.initialize();
    repo.paused = true;
    final operation = c.send('q');
    await repo.waiting.future;
    final refresh = c.refresh();
    await Future<void>.delayed(Duration.zero);
    repo.release.complete();
    await Future.wait([operation, refresh]);
    expect(tutor.requests, hasLength(1));
    expect(c.phase, ChatPhase.ready);
    expect(await roles(c), ['USER', 'ASSISTANT']);
  });
  test(
    'USER commits before Tutor and supported ASSISTANT persists after',
    () async {
      final c = create();
      await c.initialize();
      tutor.respond = (request) async {
        expect(await roles(c), ['USER']);
        expect(request.question, 'question');
        return replyFor(request);
      };
      await c.send('question');
      expect(await roles(c), ['USER', 'ASSISTANT']);
      expect(c.messages.last.sources, [testSource]);
      expect(c.lastResult!.status, TutorStatus.answer);
    },
  );
  test('default unavailable AI keeps USER and returns typed error', () async {
    final c = create(port: const UnavailableTutorPort());
    await c.initialize();
    await c.send('question');
    expect(await roles(c), ['USER']);
    expect(c.failure!.tutorError, TutorErrorCode.resourceNotReady);
    await c.retry();
    await c.retry();
    expect(await roles(c), ['USER']);
  });
  test(
    'concurrent duplicate send shares one persistence and Tutor request',
    () async {
      final c = create();
      await c.initialize();
      final response = Completer<TutorReply>();
      tutor.respond = (_) => response.future;
      final one = c.send('q');
      final two = c.send('q');
      await tutor.started.future;
      expect(tutor.requests, hasLength(1));
      response.complete(replyFor(tutor.requests.single));
      await Future.wait([one, two]);
      expect(await roles(c), ['USER', 'ASSISTANT']);
    },
  );
  test(
    'follow-up remains in the same conversation with prior context',
    () async {
      final c = create();
      await c.initialize();
      await c.send('first');
      final id = c.conversationId;
      await c.send('follow up');
      expect(c.conversationId, id);
      expect(await roles(c), ['USER', 'ASSISTANT', 'USER', 'ASSISTANT']);
      expect(tutor.requests.last.history.map((m) => m.text), contains('first'));
      expect(
        await f.conversations.listConversations(
          userId: f.session.userId,
          accountEpoch: f.session.accountEpoch,
        ),
        hasLength(1),
      );
    },
  );
  test('failed generation retry does not insert USER a second time', () async {
    final c = create();
    await c.initialize();
    tutor.respond = (_) => throw StateError('isolated runtime failure');
    await c.send('q');
    expect(await roles(c), ['USER']);
    final firstRequest = tutor.requests.single.requestId;
    tutor.respond = replyFor;
    await c.retry();
    expect(await roles(c), ['USER', 'ASSISTANT']);
    expect(tutor.requests.last.requestId, isNot(firstRequest));
  });
  test('partial warning survives reopen through saved answer text', () async {
    final c = create();
    await c.initialize();
    tutor.respond = (r) => replyFor(
      r,
      result: TutorResult.answer('supported subpart', [
        testSource,
      ], partial: true),
    );
    await c.send('q');
    expect(c.lastResult!.isPartial, true);
    final reopened = create(id: c.conversationId);
    await reopened.initialize();
    expect(reopened.messages.last.text, contains('إجابة جزئية'));
    expect(reopened.messages.last.sources, [testSource]);
  });
  test('refusal is not stored as a fabricated sourced answer', () async {
    final c = create();
    await c.initialize();
    tutor.respond = (r) =>
        replyFor(r, result: TutorResult.refusal(TutorReason.noEvidence));
    await c.send('q');
    expect(c.lastResult!.status, TutorStatus.refusal);
    expect(c.messages.last.sources, isEmpty);
    expect(c.messages.last.text, contains('أدلة'));
  });
  test('Cancel settles promptly and ignores a late successful reply', () async {
    final c = create();
    await c.initialize();
    final response = Completer<TutorReply>();
    tutor.respond = (_) => response.future;
    final operation = c.send('q');
    await tutor.started.future;
    await c.cancel().timeout(const Duration(seconds: 2));
    await operation;
    expect(c.isBusy, false);
    expect(c.canRetry, true);
    response.complete(replyFor(tutor.requests.first));
    await Future<void>.delayed(Duration.zero);
    expect(await roles(c), ['USER']);
    tutor.respond = replyFor;
    await c.retry();
    expect(await roles(c), ['USER', 'ASSISTANT']);
  });
  test(
    'Logout invalidates pending request and clears private UI state',
    () async {
      final c = create();
      await c.initialize();
      final response = Completer<TutorReply>();
      tutor.respond = (_) => response.future;
      final operation = c.send('q');
      await tutor.started.future;
      await f.logout();
      await operation.timeout(const Duration(seconds: 2));
      expect(c.phase, ChatPhase.sessionExpired);
      expect(c.messages, isEmpty);
      response.complete(replyFor(tutor.requests.single));
      await Future<void>.delayed(Duration.zero);
      expect(await roles(c), ['USER']);
    },
  );
  test(
    'Delete invalidates pending reply and cascades the saved USER',
    () async {
      final c = create();
      await c.initialize();
      final response = Completer<TutorReply>();
      tutor.respond = (_) => response.future;
      final operation = c.send('q');
      await tutor.started.future;
      await f.users.deleteAccount(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
      );
      await operation.timeout(const Duration(seconds: 2));
      response.complete(replyFor(tutor.requests.single));
      await Future<void>.delayed(Duration.zero);
      expect(c.messages, isEmpty);
      expect(await roles(c), isEmpty);
    },
  );
  for (final mode in ['revision', 'unapproved', 'identity']) {
    test('rejects $mode mismatch without assistant persistence', () async {
      final c = create();
      await c.initialize();
      tutor.respond = (r) => mode == 'identity'
          ? TutorReply(
              requestId: 'old',
              userId: r.userId,
              accountEpoch: r.accountEpoch,
              conversationId: r.conversationId,
              datasetRevision: r.datasetRevision,
              result: TutorResult.answer('bad', [testSource]),
              approvedSources: [testSource],
            )
          : replyFor(
              r,
              revision: mode == 'revision' ? 'wrong' : null,
              approved: mode == 'unapproved' ? [] : [testSource],
            );
      await c.send('q');
      expect(await roles(c), ['USER']);
      expect(c.failure!.code, ChatFailureCode.invalidResponse);
    });
  }
  test('assistant SQLite failure keeps USER and retry is safe', () async {
    final c = create();
    await c.initialize();
    await f.db.customStatement(
      "CREATE TRIGGER fail_assistant BEFORE INSERT ON message WHEN NEW.role='ASSISTANT' BEGIN SELECT RAISE(ABORT, 'isolated write'); END;",
    );
    await c.send('q');
    expect(c.failure!.code, ChatFailureCode.persistenceFailure);
    expect(await roles(c), ['USER']);
    await f.db.customStatement('DROP TRIGGER fail_assistant');
    await c.retry();
    expect(await roles(c), ['USER', 'ASSISTANT']);
  });
  test('source resolver cannot substitute another dataset revision', () async {
    final c = create();
    await c.initialize();
    await c.send('q');
    resolver.respond = (_) => const ResolvedSource(
      reference: SourceReference(
        packId: 'fixture-biology',
        chunkId: 'fixture-chunk',
        datasetRevision: 'wrong',
      ),
      snippet: 'wrong revision',
    );
    expect(await c.resolveSource(testSource), isNull);
  });
  test(
    'malformed historical source metadata is unavailable, not fabricated',
    () async {
      final c = create();
      await c.initialize();
      await c.send('q');
      await f.db.customStatement(
        "UPDATE message SET source_refs_json='invalid' WHERE role='ASSISTANT'",
      );
      final reopened = create(id: c.conversationId);
      await reopened.initialize();
      expect(reopened.messages.last.sourcesUnavailable, true);
      expect(reopened.messages.last.sources, isEmpty);
    },
  );
  test('saved history reopens through a new SQLite connection', () async {
    await f.close();
    fixtureOpen = false;
    final dir = await Directory.systemTemp.createTemp('siraj_b08_reopen_');
    final file = File('${dir.path}/chat.sqlite');
    final fixture = ChatFixture(
      database: AppDatabase.forTesting(NativeDatabase(file)),
    );
    await fixture.initialize();
    final first = ChatTurnCoordinator(
      session: fixture.session,
      conversations: fixture.conversations,
      guard: fixture.guard,
      tutor: FakeTutor(),
    );
    await first.initialize();
    await first.send('saved question');
    final id = first.conversationId;
    first.dispose();
    await fixture.close();
    final reopenedDb = AppDatabase.forTesting(NativeDatabase(file));
    final reopened = ChatTurnCoordinator(
      session: fixture.session,
      conversations: ConversationRepository(reopenedDb),
      guard: SessionGuard(UserRepository(reopenedDb)),
      tutor: FakeTutor(),
      conversationId: id,
    );
    try {
      await reopened.initialize();
      expect(reopened.messages.map((m) => m.text), contains('saved question'));
      expect(reopened.messages.last.sources, [testSource]);
    } finally {
      reopened.dispose();
      await reopenedDb.close();
      await dir.delete(recursive: true);
    }
  });

  test(
    'a newer USER supersedes a reply pending in another coordinator',
    () async {
      final first = create();
      await first.initialize();
      await first.send('initial');
      final late = Completer<TutorReply>();
      tutor.respond = (_) => late.future;
      final oldOperation = first.send('old pending question');
      while (tutor.requests.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      final oldRequest = tutor.requests.last;
      final newer = create(id: first.conversationId);
      await newer.initialize();
      tutor.respond = replyFor;
      await newer.send('new question');
      late.complete(replyFor(oldRequest));
      await oldOperation;
      final rows = await f.conversations.listMessages(
        userId: f.session.userId,
        accountEpoch: f.session.accountEpoch,
        conversationId: first.conversationId!,
      );
      expect(
        rows.where((row) => row.read<String>('role') == 'ASSISTANT'),
        hasLength(2),
      );
    },
  );

  test(
    'coarse or backwards wall clock cannot reorder follow-up messages',
    () async {
      final c = ChatTurnCoordinator(
        session: f.session,
        conversations: f.conversations,
        guard: f.guard,
        tutor: tutor,
        newId: () => 'descending-${1000 - serial++}',
        clock: () => DateTime.utc(2026, 10, 22),
      );
      coordinators.add(c);
      await c.initialize();
      for (var i = 0; i < 12; i++) {
        await c.send('question $i');
      }
      expect(
        c.messages
            .map((m) => m.text)
            .where((text) => text.startsWith('question'))
            .toList(),
        [for (var i = 0; i < 12; i++) 'question $i'],
      );
      expect(c.messages, hasLength(24));
    },
  );

  test(
    'Logout during Cancel settlement cannot re-enable the expired session',
    () async {
      final repo = PausedChatRead(f.db);
      final c = ChatTurnCoordinator(
        session: f.session,
        conversations: repo,
        guard: f.guard,
        tutor: tutor,
      );
      coordinators.add(c);
      await c.initialize();
      final response = Completer<TutorReply>();
      tutor.respond = (_) => response.future;
      final operation = c.send('q');
      await tutor.started.future;
      repo.paused = true;
      final cancel = c.cancel();
      await repo.waiting.future;
      await f.logout();
      repo.release.complete();
      await cancel;
      await operation;
      response.complete(replyFor(tutor.requests.single));
      expect(c.phase, ChatPhase.sessionExpired);
      expect(c.canSend, false);
      expect(c.messages, isEmpty);
    },
  );
  test(
    'Cancel before assistant SQL begins prevents the delayed write',
    () async {
      final repo = PausedChatWrite(f.db);
      final c = ChatTurnCoordinator(
        session: f.session,
        conversations: repo,
        guard: f.guard,
        tutor: tutor,
      );
      coordinators.add(c);
      await c.initialize();
      final operation = c.send('q');
      await repo.waiting.future;
      final cancel = c.cancel();
      repo.release.complete();
      await cancel;
      await operation;
      expect(await roles(c), ['USER']);
      expect(c.canRetry, true);
    },
  );
  test(
    'disposing a pending turn consumes late adapter errors without writes',
    () async {
      final c = create();
      await c.initialize();
      final response = Completer<TutorReply>();
      tutor.respond = (_) => response.future;
      final operation = c.send('q');
      await tutor.started.future;
      c.dispose();
      await operation;
      response.completeError(StateError('late isolated error'));
      await Future<void>.delayed(Duration.zero);
      expect(await roles(c), ['USER']);
    },
  );
}
