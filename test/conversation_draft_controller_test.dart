import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';

void main() {
  group('B-05 first-message draft contract', () {
    late AppDatabase db;
    late UserRepository users;
    late ConversationRepository conversations;
    late SessionGuard guard;
    late AuthSession session;
    var index = 0;

    String nextId() => 'b05-id-${index++}';
    ConversationDraftController draft() => ConversationDraftController(
      conversations: conversations,
      guard: guard,
      newId: nextId,
      clock: () => DateTime.utc(2026, 10, 22),
    );
    Future<List<QueryRow>> list() => conversations.listConversations(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
    );

    setUp(() async {
      index = 0;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      users = UserRepository(db);
      conversations = ConversationRepository(db);
      guard = SessionGuard(users);
      session = const AuthSession(
        userId: 'u-1',
        accountEpoch: 'epoch-1',
        sessionNonce: 'nonce-that-is-not-in-sqlite',
      );
      await users.create(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        usernameNormalized: 'student',
        usernameDisplay: 'Student',
        passwordSalt: Uint8List.fromList([1, 2]),
        passwordHash: Uint8List.fromList([3, 4]),
        passwordParamsJson: '{"iterations":1000}',
        nowUtc: '2026-10-22T00:00:00.000Z',
      );
      final nonceHash = await Sha256().hash(utf8.encode(session.sessionNonce));
      await users.setNonceHash(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        hash: Uint8List.fromList(nonceHash.bytes),
        nowUtc: '2026-10-22T00:00:00.000Z',
      );
    });
    tearDown(() async => db.close());

    test(
      'open draft persists nothing; blank input does not create rows',
      () async {
        final controller = draft();
        expect(controller.isTemporary, isTrue);
        expect(await list(), isEmpty);
        await expectLater(
          controller.commitFirstQuestion(session: session, question: '   '),
          throwsArgumentError,
        );
        expect(await list(), isEmpty);
        expect(controller.isTemporary, isTrue);
      },
    );

    test(
      'first valid message creates exactly one saved conversation',
      () async {
        final controller = draft();
        final conversationId = await controller.commitFirstQuestion(
          session: session,
          question: '  ما وظيفة الخلية؟  ',
        );
        expect(controller.isTemporary, isFalse);
        expect(controller.conversationId, conversationId);
        final rows = await list();
        expect(rows, hasLength(1));
        final messages = await conversations.listMessages(
          userId: session.userId,
          accountEpoch: session.accountEpoch,
          conversationId: conversationId,
        );
        expect(messages, hasLength(1));
        expect(messages.single.read<String>('content'), 'ما وظيفة الخلية؟');
      },
    );

    test(
      'repeated first-send reuses same conversation without duplication',
      () async {
        final controller = draft();
        final first = controller.commitFirstQuestion(
          session: session,
          question: 'سؤال واحد',
        );
        final second = controller.commitFirstQuestion(
          session: session,
          question: 'سؤال واحد',
        );
        expect(identical(first, second), isTrue);
        final id = await first;
        expect(await second, id);
        expect(
          await controller.commitFirstQuestion(
            session: session,
            question: '  سؤال واحد  ',
          ),
          id,
        );
        await expectLater(
          controller.commitFirstQuestion(
            session: session,
            question: 'سؤال مختلف',
          ),
          throwsStateError,
        );
        expect(await list(), hasLength(1));
      },
    );

    test('invalidated nonce blocks committing a draft', () async {
      await users.invalidateNonce(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        nowUtc: '2026-10-22T00:00:01.000Z',
      );
      final controller = draft();
      await expectLater(
        controller.commitFirstQuestion(session: session, question: 'سؤال'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.code,
            'code',
            AuthFailureCode.sessionInvalid,
          ),
        ),
      );
      expect(controller.isTemporary, isTrue);
      expect(await list(), isEmpty);
    });

    test('ten saved chats; next first send evicts oldest atomically', () async {
      for (var i = 0; i < 11; i++) {
        await draft().commitFirstQuestion(
          session: session,
          question: 'السؤال $i',
        );
      }
      expect(await list(), hasLength(10));
    });
  });
}
