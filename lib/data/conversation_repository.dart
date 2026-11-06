import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Persistence only: no LLM call. The UI draft is not stored.
/// The B-05 controller supplies stable IDs, session guard, duplicate-send
/// protection and invokes the Tutor service after commit.
class ConversationRepository {
  final AppDatabase db;
  const ConversationRepository(this.db);

  /// Atomic first message + max 10; older messages cascade on eviction.
  /// On retry with the same messageId and same question, returns its chat ID.
  Future<String> saveFirstUserMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String question,
    required String nowUtc,
    Uint8List? expectedNonceHash,
  }) async {
    final validatedQuestion = question.trim();
    if (validatedQuestion.isEmpty ||
        conversationId.trim().isEmpty ||
        messageId.trim().isEmpty ||
        userId.trim().isEmpty ||
        accountEpoch.trim().isEmpty) {
      throw ArgumentError('Blank/invalid first message');
    }
    return db.transaction(() async {
      if (expectedNonceHash != null) {
        await _requireSession(userId, accountEpoch, expectedNonceHash);
      }
      final existing = await db
          .customSelect(
            '''
        SELECT m.content, c.conversation_id FROM message m
        JOIN conversation c ON c.conversation_id = m.conversation_id
        JOIN user_profile u ON u.user_id = c.user_id
        WHERE m.message_id = ? AND c.user_id = ? AND u.account_epoch = ?
          AND m.role = 'USER'
      ''',
            variables: [
              Variable.withString(messageId),
              Variable.withString(userId),
              Variable.withString(accountEpoch),
            ],
          )
          .getSingleOrNull();
      if (existing != null) {
        if (existing.read<String>('content') != validatedQuestion ||
            existing.read<String>('conversation_id') != conversationId) {
          throw StateError('Message ID already used with different payload');
        }
        return conversationId;
      }

      final owner = await db
          .customSelect(
            '''
        SELECT user_id FROM user_profile WHERE user_id = ? AND account_epoch = ?
      ''',
            variables: [
              Variable.withString(userId),
              Variable.withString(accountEpoch),
            ],
          )
          .getSingleOrNull();
      if (owner == null) throw StateError('Account/session epoch unavailable');

      final count = await db
          .customSelect(
            '''
        SELECT COUNT(*) AS n FROM conversation WHERE user_id = ?
      ''',
            variables: [Variable.withString(userId)],
          )
          .getSingle();
      if (count.read<int>('n') >= 10) {
        await db.customUpdate(
          '''
          DELETE FROM conversation WHERE conversation_id = (
            SELECT conversation_id FROM conversation WHERE user_id = ?
            ORDER BY created_at ASC, conversation_id ASC LIMIT 1
          ) AND user_id = ?
        ''',
          variables: [Variable.withString(userId), Variable.withString(userId)],
        );
      }
      await db.customInsert(
        '''
        INSERT INTO conversation (conversation_id, user_id, created_at, updated_at)
        VALUES (?, ?, ?, ?)
      ''',
        variables: [
          Variable.withString(conversationId),
          Variable.withString(userId),
          Variable.withString(nowUtc),
          Variable.withString(nowUtc),
        ],
      );
      await db.customInsert(
        '''
        INSERT INTO message (message_id, conversation_id, role, content,
          source_refs_json, created_at)
        VALUES (?, ?, 'USER', ?, '[]', ?)
      ''',
        variables: [
          Variable.withString(messageId),
          Variable.withString(conversationId),
          Variable.withString(validatedQuestion),
          Variable.withString(nowUtc),
        ],
      );
      return conversationId;
    });
  }

  Future<List<QueryRow>> listConversations({
    required String userId,
    required String accountEpoch,
  }) => db
      .customSelect(
        '''
      SELECT c.* FROM conversation c
      JOIN user_profile u ON u.user_id=c.user_id
      WHERE c.user_id = ? AND u.account_epoch = ?
      ORDER BY c.created_at DESC, c.conversation_id DESC
    ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(accountEpoch),
        ],
      )
      .get();

  Future<List<QueryRow>> listMessages({
    required String userId,
    required String accountEpoch,
    required String conversationId,
  }) => db
      .customSelect(
        '''
      SELECT m.* FROM message m
      JOIN conversation c ON c.conversation_id=m.conversation_id
      JOIN user_profile u ON u.user_id=c.user_id
      WHERE c.user_id = ? AND u.account_epoch = ? AND c.conversation_id = ?
      ORDER BY m.created_at ASC, m.message_id ASC
    ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(accountEpoch),
          Variable.withString(conversationId),
        ],
      )
      .get();

  /// Used only after the local Tutor result has passed structural/source checks.
  Future<void> appendAssistantMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String answer,
    required String sourceRefsJson,
    required String nowUtc,
    Uint8List? expectedNonceHash,
    bool Function()? isRequestCurrent,
  }) async {
    final parsed = jsonDecode(sourceRefsJson);
    if (parsed is! List || parsed.any((ref) => ref is! Map<String, dynamic>)) {
      throw FormatException('SourceRefs must be a JSON array of objects');
    }
    await db.transaction(() async {
      if (isRequestCurrent != null && !isRequestCurrent()) {
        throw StateError('Request cancelled');
      }
      if (expectedNonceHash != null) {
        await _requireSession(userId, accountEpoch, expectedNonceHash);
      }
      if (await _existingMessage(
        userId,
        accountEpoch,
        conversationId,
        messageId,
        'ASSISTANT',
        answer,
        sourceRefsJson,
      )) {
        return;
      }
      final inserted = await db.customUpdate(
        '''
      INSERT INTO message (message_id, conversation_id, role, content,
        source_refs_json, created_at)
      SELECT ?, c.conversation_id, 'ASSISTANT', ?, ?, ?
      FROM conversation c JOIN user_profile u ON u.user_id=c.user_id
      WHERE c.conversation_id = ? AND c.user_id = ? AND u.account_epoch = ?
    ''',
        variables: [
          Variable.withString(messageId),
          Variable.withString(answer),
          Variable.withString(sourceRefsJson),
          Variable.withString(nowUtc),
          Variable.withString(conversationId),
          Variable.withString(userId),
          Variable.withString(accountEpoch),
        ],
      );
      if (inserted != 1) {
        throw StateError('Conversation/session no longer active');
      }
      if (isRequestCurrent != null && !isRequestCurrent()) {
        throw StateError('Request cancelled');
      }
    });
  }

  Future<void> _requireSession(
    String userId,
    String epoch,
    Uint8List nonceHash,
  ) async {
    final row = await db
        .customSelect(
          'SELECT user_id FROM user_profile WHERE user_id=? AND account_epoch=? AND active_session_nonce_hash=?',
          variables: [
            Variable.withString(userId),
            Variable.withString(epoch),
            Variable.withBlob(nonceHash),
          ],
        )
        .getSingleOrNull();
    if (nonceHash.length != 32 || row == null) {
      throw StateError('Session no longer current');
    }
  }

  Future<bool> _existingMessage(
    String userId,
    String epoch,
    String conversationId,
    String messageId,
    String role,
    String content,
    String refs,
  ) async {
    final row = await db
        .customSelect(
          'SELECT m.* FROM message m JOIN conversation c ON c.conversation_id=m.conversation_id JOIN user_profile u ON u.user_id=c.user_id WHERE m.message_id=? AND c.user_id=? AND u.account_epoch=?',
          variables: [
            Variable.withString(messageId),
            Variable.withString(userId),
            Variable.withString(epoch),
          ],
        )
        .getSingleOrNull();
    if (row == null) return false;
    if (row.read<String>('conversation_id') != conversationId ||
        row.read<String>('role') != role ||
        row.read<String>('content') != content ||
        row.read<String>('source_refs_json') != refs) {
      throw StateError('Message ID payload conflict');
    }
    return true;
  }

  /// Follow-up in the existing conversation; retry is idempotent. Session
  /// hash is checked in the same transaction as the ownership check and insert.
  Future<void> saveUserFollowUp({
    required String userId,
    required String accountEpoch,
    required Uint8List expectedNonceHash,
    required String conversationId,
    required String messageId,
    required String question,
    required String nowUtc,
  }) async {
    final content = question.trim();
    if (content.isEmpty || messageId.trim().isEmpty) {
      throw ArgumentError('Blank follow-up');
    }
    await db.transaction(() async {
      await _requireSession(userId, accountEpoch, expectedNonceHash);
      if (await _existingMessage(
        userId,
        accountEpoch,
        conversationId,
        messageId,
        'USER',
        content,
        '[]',
      )) {
        return;
      }
      final inserted = await db.customUpdate(
        "INSERT INTO message (message_id,conversation_id,role,content,source_refs_json,created_at) SELECT ?,c.conversation_id,'USER',?,'[]',? FROM conversation c JOIN user_profile u ON u.user_id=c.user_id WHERE c.conversation_id=? AND c.user_id=? AND u.account_epoch=?",
        variables: [
          Variable.withString(messageId),
          Variable.withString(content),
          Variable.withString(nowUtc),
          Variable.withString(conversationId),
          Variable.withString(userId),
          Variable.withString(accountEpoch),
        ],
      );
      if (inserted != 1) throw StateError('Conversation no longer exists');
    });
  }

  Future<int> deleteConversation({
    required String userId,
    required String accountEpoch,
    required String conversationId,
  }) => db.customUpdate(
    '''
      DELETE FROM conversation WHERE user_id = ? AND conversation_id = ?
      AND EXISTS (SELECT 1 FROM user_profile u WHERE u.user_id = ?
        AND u.account_epoch = ?)
    ''',
    variables: [
      Variable.withString(userId),
      Variable.withString(conversationId),
      Variable.withString(userId),
      Variable.withString(accountEpoch),
    ],
  );
}
