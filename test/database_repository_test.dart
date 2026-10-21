import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/resource_repository.dart';
import 'package:siraj/data/settings_repository.dart';
import 'package:siraj/data/user_repository.dart';

const _utc = '2026-10-21T00:00:00.000Z';

void main() {
  group('B-03 repositories and atomic SQLite behavior', () {
    late AppDatabase db;
    late UserRepository users;
    late ConversationRepository chats;
    late SettingsRepository settings;
    late ResourceRepository resources;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      users = UserRepository(db);
      chats = ConversationRepository(db);
      settings = SettingsRepository(db);
      resources = ResourceRepository(db);
    });
    tearDown(() async => db.close());

    Future<void> insertAccount() => users.create(
      userId: 'u1',
      accountEpoch: 'epoch-1',
      usernameNormalized: 'student',
      usernameDisplay: 'Student',
      passwordSalt: Uint8List.fromList([1, 2, 3, 4]),
      passwordHash: Uint8List.fromList([5, 6, 7, 8]),
      passwordParamsJson: '{"iterations":100000}',
      nowUtc: _utc,
    );

    test('singleton user and epoch-protected nonce updates', () async {
      await insertAccount();
      expect((await users.currentAccount())?.read<String>('user_id'), 'u1');
      expect(
        await users.setNonceHash(
          userId: 'u1',
          accountEpoch: 'old-epoch',
          hash: Uint8List.fromList([1, 2]),
          nowUtc: _utc,
        ),
        0,
      );
      expect(
        await users.setNonceHash(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          hash: Uint8List.fromList([1, 2]),
          nowUtc: _utc,
        ),
        1,
      );
      expect(
        await users.invalidateNonce(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          nowUtc: _utc,
        ),
        1,
      );
      await expectLater(insertAccount(), throwsA(isA<Exception>()));
    });

    test('settings are scoped to owner and account epoch', () async {
      await insertAccount();
      expect(
        await settings.write(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          key: 'theme',
          valueJson: '"dark"',
          nowUtc: _utc,
        ),
        1,
      );
      expect(
        await settings.read(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          key: 'theme',
        ),
        '"dark"',
      );
      expect(
        await settings.write(
          userId: 'u1',
          accountEpoch: 'stale',
          key: 'theme',
          valueJson: '"light"',
          nowUtc: _utc,
        ),
        0,
      );
      expect(
        await settings.read(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          key: 'theme',
        ),
        '"dark"',
      );
      expect(
        await settings.write(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          key: 'theme',
          valueJson: '"light"',
          nowUtc: _utc,
        ),
        1,
      );
      expect(
        await settings.remove(
          userId: 'u1',
          accountEpoch: 'stale',
          key: 'theme',
        ),
        0,
      );
      expect(
        await settings.remove(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          key: 'theme',
        ),
        1,
      );
    });

    test(
      'device resources remain separate and READY cannot be set directly',
      () async {
        await insertAccount();
        await resources.recordUnverified(
          kind: 'LLM',
          resourceId: 'model-A',
          state: 'MISSING',
          nowUtc: _utc,
        );
        await resources.recordUnverified(
          kind: 'PDF',
          resourceId: 'biology-book',
          state: 'FAILED',
          nowUtc: _utc,
        );
        expect(
          (await resources.find(
            kind: 'LLM',
            resourceId: 'model-A',
          ))?.read<String>('state'),
          'MISSING',
        );
        expect(
          () => resources.recordUnverified(
            kind: 'RAG_PACK',
            resourceId: 'bio',
            state: 'READY',
            nowUtc: _utc,
          ),
          throwsArgumentError,
        );
        expect(
          await users.deleteAccount(userId: 'u1', accountEpoch: 'epoch-1'),
          1,
        );
        expect(
          (await resources.find(
            kind: 'PDF',
            resourceId: 'biology-book',
          ))?.read<String>('state'),
          'FAILED',
        );
      },
    );

    test('blank drafts do not persist anything', () async {
      await insertAccount();
      await expectLater(
        chats.saveFirstUserMessage(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          conversationId: 'draft',
          messageId: 'm-draft',
          question: '   ',
          nowUtc: _utc,
        ),
        throwsArgumentError,
      );
      expect(
        await chats.listConversations(userId: 'u1', accountEpoch: 'epoch-1'),
        isEmpty,
      );
    });

    test(
      'first send commits atomically, evicts oldest at 11, retries idempotently',
      () async {
        await insertAccount();
        for (var i = 0; i < 10; i++) {
          await chats.saveFirstUserMessage(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c${i.toString().padLeft(2, '0')}',
            messageId: 'm$i',
            question: 'Question $i',
            nowUtc: _utc,
          );
        }
        expect(
          (await chats.listConversations(
            userId: 'u1',
            accountEpoch: 'epoch-1',
          )).length,
          10,
        );

        expect(
          await chats.saveFirstUserMessage(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c10',
            messageId: 'm10',
            question: 'New question',
            nowUtc: _utc,
          ),
          'c10',
        );
        final conversations = await chats.listConversations(
          userId: 'u1',
          accountEpoch: 'epoch-1',
        );
        expect(conversations.length, 10);
        expect(
          conversations.map((r) => r.read<String>('conversation_id')),
          isNot(contains('c00')),
        );
        expect(
          conversations.map((r) => r.read<String>('conversation_id')),
          contains('c10'),
        );

        expect(
          await chats.saveFirstUserMessage(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c10',
            messageId: 'm10',
            question: 'New question',
            nowUtc: _utc,
          ),
          'c10',
        );
        expect(
          (await chats.listConversations(
            userId: 'u1',
            accountEpoch: 'epoch-1',
          )).length,
          10,
        );
        expect(
          (await chats.listMessages(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c10',
          )).length,
          1,
        );
      },
    );

    test(
      'failed insert rolls back eviction and retains old messages',
      () async {
        await insertAccount();
        for (var i = 0; i < 10; i++) {
          await chats.saveFirstUserMessage(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c$i',
            messageId: 'm$i',
            question: 'Question $i',
            nowUtc: _utc,
          );
        }
        await expectLater(
          chats.saveFirstUserMessage(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c9',
            messageId: 'different-message-id',
            question: 'Collision',
            nowUtc: _utc,
          ),
          throwsA(isA<Exception>()),
        );
        final chatsAfter = await chats.listConversations(
          userId: 'u1',
          accountEpoch: 'epoch-1',
        );
        expect(chatsAfter.length, 10);
        expect(
          chatsAfter.map((r) => r.read<String>('conversation_id')),
          contains('c0'),
        );
        expect(
          (await chats.listMessages(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c0',
          )).length,
          1,
        );
      },
    );

    test(
      'assistant writes enforce epoch and JSON source-reference format',
      () async {
        await insertAccount();
        await chats.saveFirstUserMessage(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          conversationId: 'c1',
          messageId: 'm1',
          question: 'Biology?',
          nowUtc: _utc,
        );
        await expectLater(
          chats.appendAssistantMessage(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c1',
            messageId: 'a-invalid',
            answer: 'Answer',
            sourceRefsJson: '{"bad":1}',
            nowUtc: _utc,
          ),
          throwsFormatException,
        );
        await expectLater(
          chats.appendAssistantMessage(
            userId: 'u1',
            accountEpoch: 'stale',
            conversationId: 'c1',
            messageId: 'a-stale',
            answer: 'Answer',
            sourceRefsJson: '[]',
            nowUtc: _utc,
          ),
          throwsStateError,
        );
        await chats.appendAssistantMessage(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          conversationId: 'c1',
          messageId: 'a1',
          answer: 'Evidence-backed answer',
          sourceRefsJson: '[]',
          nowUtc: _utc,
        );
        expect(
          (await chats.listMessages(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c1',
          )).length,
          2,
        );
        expect(
          await chats.listMessages(
            userId: 'u1',
            accountEpoch: 'stale',
            conversationId: 'c1',
          ),
          isEmpty,
        );
      },
    );

    test(
      'deletion cascades messages; account deletion preserves device registry',
      () async {
        await insertAccount();
        await resources.recordUnverified(
          kind: 'RAG_EMBEDDING',
          resourceId: 'shared-embed',
          state: 'MISSING',
          nowUtc: _utc,
        );
        await chats.saveFirstUserMessage(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          conversationId: 'c1',
          messageId: 'm1',
          question: 'Question',
          nowUtc: _utc,
        );
        expect(
          await chats.deleteConversation(
            userId: 'u1',
            accountEpoch: 'stale',
            conversationId: 'c1',
          ),
          0,
        );
        expect(
          await chats.deleteConversation(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c1',
          ),
          1,
        );
        expect(
          await chats.listMessages(
            userId: 'u1',
            accountEpoch: 'epoch-1',
            conversationId: 'c1',
          ),
          isEmpty,
        );
        await chats.saveFirstUserMessage(
          userId: 'u1',
          accountEpoch: 'epoch-1',
          conversationId: 'c2',
          messageId: 'm2',
          question: 'Again',
          nowUtc: _utc,
        );
        expect(
          await users.deleteAccount(userId: 'u1', accountEpoch: 'stale'),
          0,
        );
        expect(
          await users.deleteAccount(userId: 'u1', accountEpoch: 'epoch-1'),
          1,
        );
        expect(
          await chats.listConversations(userId: 'u1', accountEpoch: 'epoch-1'),
          isEmpty,
        );
        expect(
          (await resources.find(
            kind: 'RAG_EMBEDDING',
            resourceId: 'shared-embed',
          ))?.read<String>('state'),
          'MISSING',
        );
      },
    );
  });
}
