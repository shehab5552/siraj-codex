import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';
import 'package:siraj/features/chat/chat_turn_coordinator.dart';
import 'package:siraj/features/chat/tutor_contracts.dart';

class PendingTutor implements TutorPort {
  final result = Completer<TutorResult>();
  int calls = 0;
  bool current = true;
  @override
  Future<TutorResult> ask(String q, TutorCancellation c) {
    calls++;
    return result.future;
  }

  @override
  bool isRevisionCurrent(String revision) => current && revision == 'test-rev';
}

void main() {
  late AppDatabase db;
  late ConversationRepository repo;
  late UserRepository users;
  late ChatTurnCoordinator turns;
  late PendingTutor tutor;
  const session = AuthSession(
    userId: 'u',
    accountEpoch: 'e',
    sessionNonce: 'test-nonce',
  );
  const now = '2026-11-06T00:00:00Z';
  TutorResult answer() => TutorResult.answer('contract-only answer', [
    SourceReference(
      packId: 'test-pack',
      chunkId: 'test-chunk',
      datasetRevision: 'test-rev',
    ),
  ]);
  Future<ChatTurnOutcome> send([
    String id = 'turn1',
    String question = 'question',
  ]) => turns.send(session: session, question: question, turnId: id);
  Future<void> waitTutor() async {
    for (var i = 0; i < 100 && tutor.calls == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(tutor.calls, 1);
  }

  Future<int> count() async => (await repo.listMessages(
    userId: 'u',
    accountEpoch: 'e',
    conversationId: turns.conversationId ?? '',
  )).length;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ConversationRepository(db);
    users = UserRepository(db);
    tutor = PendingTutor();
    await users.create(
      userId: 'u',
      accountEpoch: 'e',
      usernameNormalized: 'test',
      usernameDisplay: 'Test',
      passwordSalt: Uint8List.fromList([1]),
      passwordHash: Uint8List.fromList([2]),
      passwordParamsJson: '{}',
      nowUtc: now,
    );
    await users.setNonceHash(
      userId: 'u',
      accountEpoch: 'e',
      hash: Uint8List.fromList(
        (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
      ),
      nowUtc: now,
    );
    final guard = SessionGuard(users);
    turns = ChatTurnCoordinator(
      draft: ConversationDraftController(conversations: repo, guard: guard),
      conversations: repo,
      guard: guard,
      tutor: tutor,
    );
  });
  tearDown(() async {
    turns.dispose();
    await db.close();
  });
  test('USER persisted before tutor and validated answer appended', () async {
    final f = send();
    await waitTutor();
    expect(await count(), 1);
    tutor.result.complete(answer());
    expect((await f).result.status, TutorStatus.answer);
    expect(await count(), 2);
  });
  test('logout during generation blocks assistant write', () async {
    final f = send();
    await waitTutor();
    await users.invalidateNonce(userId: 'u', accountEpoch: 'e', nowUtc: now);
    tutor.result.complete(answer());
    expect((await f).result.reason, TutorReason.sessionInvalid);
    expect(await count(), 1);
  });
  test('delete during generation cannot recreate chat', () async {
    final f = send();
    await waitTutor();
    await repo.deleteConversation(
      userId: 'u',
      accountEpoch: 'e',
      conversationId: turns.conversationId!,
    );
    tutor.result.complete(answer());
    expect((await f).result.status, isNot(TutorStatus.answer));
    expect(await count(), 0);
  });
  test('cancel suppresses pending answer', () async {
    final f = send();
    await waitTutor();
    turns.cancel();
    tutor.result.complete(answer());
    expect((await f).result.reason, TutorReason.cancelled);
    expect(await count(), 1);
  });
  test(
    'cancellation waits and preserves operational failure without assistant write',
    () async {
      var completed = false;
      final result = send().then((value) {
        completed = true;
        return value;
      });
      await waitTutor();
      turns.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      await expectLater(send('turn2'), throwsStateError);
      tutor.result.complete(TutorResult.error(TutorReason.generationFailed));
      expect((await result).result.reason, TutorReason.generationFailed);
      expect(await count(), 1);
    },
  );
  test('concurrent send rejected and Tutor failure preserves USER', () async {
    final f = send();
    await waitTutor();
    await expectLater(send('turn2'), throwsStateError);
    tutor.result.complete(TutorResult.error(TutorReason.runtimeUnavailable));
    expect((await f).result.status, TutorStatus.error);
    expect(await count(), 1);
  });
  test('follow-up same conversation, retry does not duplicate', () async {
    tutor.result.complete(TutorResult.error(TutorReason.resourcesUnavailable));
    final first = await send();
    await send('turn2', 'follow-up');
    await send('turn2', 'follow-up');
    expect(turns.conversationId, first.conversationId);
    expect(await count(), 2);
  });
  test('revision changes before saving suppress answer', () async {
    final f = send();
    await waitTutor();
    tutor.current = false;
    tutor.result.complete(answer());
    expect((await f).result.reason, TutorReason.sourceUnavailable);
    expect(await count(), 1);
  });
  test('dispose before result prevents persistence', () async {
    final f = send();
    await waitTutor();
    turns.dispose();
    tutor.result.complete(answer());
    expect((await f).result.reason, TutorReason.cancelled);
    expect(await count(), 1);
  });
}
