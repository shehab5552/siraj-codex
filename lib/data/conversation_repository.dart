import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

enum ChatPersistenceFailureCode {
  sessionExpired,
  conversationMissing,
  requestCancelled,
  messageConflict,
}

class ChatPersistenceFailure implements Exception {
  const ChatPersistenceFailure(this.code);
  final ChatPersistenceFailureCode code;
}

/// Describes only this committed transaction, never a guessed preflight count.
class FirstUserMessageCommit {
  const FirstUserMessageCommit(
    this.conversationId, {
    this.evictedOldest = false,
  });
  final String conversationId;
  final bool evictedOldest;
}

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
    Uint8List? sessionNonceHash,
    bool Function()? isRequestCurrent,
  }) async => (await saveFirstUserMessageWithOutcome(
    userId: userId,
    accountEpoch: accountEpoch,
    conversationId: conversationId,
    messageId: messageId,
    question: question,
    nowUtc: nowUtc,
    sessionNonceHash: sessionNonceHash,
    isRequestCurrent: isRequestCurrent,
  )).conversationId;

  /// Same atomic operation with a post-COMMIT eviction outcome for the UI.
  /// Idempotent recovery never reports a second deletion.
  Future<FirstUserMessageCommit> saveFirstUserMessageWithOutcome({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String question,
    required String nowUtc,
    Uint8List? sessionNonceHash,
    bool Function()? isRequestCurrent,
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
      _checkRequest(isRequestCurrent);
      if (sessionNonceHash != null) {
        await _requireAccess(userId, accountEpoch, sessionNonceHash);
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
        _checkRequest(isRequestCurrent);
        return FirstUserMessageCommit(conversationId);
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
      var evictedOldest = false;
      if (count.read<int>('n') >= 10) {
        final removed = await db.customUpdate(
          '''
          DELETE FROM conversation WHERE conversation_id = (
            SELECT conversation_id FROM conversation WHERE user_id = ?
            ORDER BY created_at ASC, conversation_id ASC LIMIT 1
          ) AND user_id = ?
        ''',
          variables: [Variable.withString(userId), Variable.withString(userId)],
          updates: {db.conversation, db.message},
        );
        evictedOldest = removed > 0;
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
        updates: {db.conversation},
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
        updates: {db.message},
      );
      _checkRequest(isRequestCurrent);
      return FirstUserMessageCommit(
        conversationId,
        evictedOldest: evictedOldest,
      );
    });
  }

  Future<List<QueryRow>> listConversations({
    required String userId,
    required String accountEpoch,
    Uint8List? sessionNonceHash,
  }) => db
      .customSelect(
        '''
      SELECT c.*, (SELECT m.content FROM message m
        WHERE m.conversation_id = c.conversation_id AND m.role = 'USER'
        ORDER BY m.rowid ASC LIMIT 1) AS first_question FROM conversation c
      JOIN user_profile u ON u.user_id=c.user_id
      WHERE c.user_id = ? AND u.account_epoch = ?
        ${sessionNonceHash == null ? '' : 'AND u.active_session_nonce_hash = ?'}
      ORDER BY c.created_at DESC, c.conversation_id DESC
    ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(accountEpoch),
          if (sessionNonceHash != null) Variable.withBlob(sessionNonceHash),
        ],
      )
      .get();

  Future<List<QueryRow>> listMessages({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    Uint8List? sessionNonceHash,
  }) async {
    if (sessionNonceHash != null) {
      await _requireAccess(userId, accountEpoch, sessionNonceHash);
      await _requireConversation(userId, accountEpoch, conversationId);
    }
    return db
        .customSelect(
          '''
      SELECT m.* FROM message m
      JOIN conversation c ON c.conversation_id=m.conversation_id
      JOIN user_profile u ON u.user_id=c.user_id
      WHERE c.user_id = ? AND u.account_epoch = ? AND c.conversation_id = ?
        ${sessionNonceHash == null ? '' : 'AND u.active_session_nonce_hash = ?'}
      ORDER BY m.rowid ASC
    ''',
          variables: [
            Variable.withString(userId),
            Variable.withString(accountEpoch),
            Variable.withString(conversationId),
            if (sessionNonceHash != null) Variable.withBlob(sessionNonceHash),
          ],
        )
        .get();
  }

  /// Used only after the local Tutor result has passed structural/source checks.
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
    final parsed = jsonDecode(sourceRefsJson);
    if (parsed is! List || parsed.any((ref) => ref is! Map<String, dynamic>)) {
      throw FormatException('SourceRefs must be a JSON array of objects');
    }
    await _appendMessage(
      userId: userId,
      accountEpoch: accountEpoch,
      conversationId: conversationId,
      messageId: messageId,
      content: answer,
      role: 'ASSISTANT',
      sourceRefsJson: sourceRefsJson,
      nowUtc: nowUtc,
      sessionNonceHash: sessionNonceHash,
      isRequestCurrent: isRequestCurrent,
      inReplyToMessageId: inReplyToMessageId,
    );
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
    updates: {db.conversation, db.message},
  );

  Future<void> appendUserMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String question,
    required String nowUtc,
    required Uint8List sessionNonceHash,
    bool Function()? isRequestCurrent,
  }) => _appendMessage(
    userId: userId,
    accountEpoch: accountEpoch,
    conversationId: conversationId,
    messageId: messageId,
    content: question.trim(),
    role: 'USER',
    sourceRefsJson: '[]',
    nowUtc: nowUtc,
    sessionNonceHash: sessionNonceHash,
    isRequestCurrent: isRequestCurrent,
  );

  Future<void> _appendMessage({
    required String userId,
    required String accountEpoch,
    required String conversationId,
    required String messageId,
    required String content,
    required String role,
    required String sourceRefsJson,
    required String nowUtc,
    required Uint8List? sessionNonceHash,
    bool Function()? isRequestCurrent,
    String? inReplyToMessageId,
  }) async {
    if (content.trim().isEmpty || messageId.trim().isEmpty) {
      throw ArgumentError('Invalid message');
    }
    await db.transaction(() async {
      _checkRequest(isRequestCurrent);
      try {
        await _requireAccess(userId, accountEpoch, sessionNonceHash);
        await _requireConversation(userId, accountEpoch, conversationId);
      } on ChatPersistenceFailure {
        // Preserve B-03's exception contract; B-08 always supplies the nonce
        // and receives the typed failure.
        if (sessionNonceHash == null) {
          throw StateError('Conversation/session no longer active');
        }
        rethrow;
      }
      final existing = await db
          .customSelect(
            'SELECT * FROM message WHERE message_id = ?',
            variables: [Variable.withString(messageId)],
          )
          .getSingleOrNull();
      if (existing != null) {
        if (existing.read<String>('conversation_id') != conversationId ||
            existing.read<String>('role') != role ||
            existing.read<String>('content') != content ||
            existing.read<String>('source_refs_json') != sourceRefsJson) {
          throw const ChatPersistenceFailure(
            ChatPersistenceFailureCode.messageConflict,
          );
        }
        _checkRequest(isRequestCurrent);
        return;
      }
      if (inReplyToMessageId != null) {
        // Fence replies superseded by a USER committed from another screen or
        // coordinator, in the same transaction as the assistant insertion.
        final latest = await db
            .customSelect(
              "SELECT message_id FROM message WHERE conversation_id = ? AND role = 'USER' ORDER BY rowid DESC LIMIT 1",
              variables: [Variable.withString(conversationId)],
            )
            .getSingleOrNull();
        if (latest?.read<String>('message_id') != inReplyToMessageId) {
          throw const ChatPersistenceFailure(
            ChatPersistenceFailureCode.messageConflict,
          );
        }
      }
      final inserted = await db.customUpdate(
        '''
        INSERT INTO message(message_id, conversation_id, role, content, source_refs_json, created_at)
        SELECT ?, c.conversation_id, ?, ?, ?, ? FROM conversation c
        JOIN user_profile u ON u.user_id = c.user_id
        WHERE c.conversation_id = ? AND c.user_id = ? AND u.account_epoch = ?
        ${sessionNonceHash == null ? '' : 'AND u.active_session_nonce_hash = ?'}
      ''',
        variables: [
          Variable.withString(messageId),
          Variable.withString(role),
          Variable.withString(content),
          Variable.withString(sourceRefsJson),
          Variable.withString(nowUtc),
          Variable.withString(conversationId),
          Variable.withString(userId),
          Variable.withString(accountEpoch),
          if (sessionNonceHash != null) Variable.withBlob(sessionNonceHash),
        ],
        updates: {db.message},
      );
      if (inserted != 1) {
        throw const ChatPersistenceFailure(
          ChatPersistenceFailureCode.sessionExpired,
        );
      }
      await db.customUpdate(
        'UPDATE conversation SET updated_at = ? WHERE conversation_id = ?',
        variables: [
          Variable.withString(nowUtc),
          Variable.withString(conversationId),
        ],
        updates: {db.conversation},
      );
      // Cancellation during an awaited write rolls back the whole transaction.
      _checkRequest(isRequestCurrent);
    });
  }

  Future<void> _requireAccess(
    String userId,
    String epoch,
    Uint8List? nonce,
  ) async {
    if (nonce != null && nonce.length != 32) {
      throw const ChatPersistenceFailure(
        ChatPersistenceFailureCode.sessionExpired,
      );
    }
    final row = await db
        .customSelect(
          'SELECT user_id FROM user_profile WHERE user_id = ? AND account_epoch = ? ${nonce == null ? '' : 'AND active_session_nonce_hash = ?'}',
          variables: [
            Variable.withString(userId),
            Variable.withString(epoch),
            if (nonce != null) Variable.withBlob(nonce),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const ChatPersistenceFailure(
        ChatPersistenceFailureCode.sessionExpired,
      );
    }
  }

  Future<void> _requireConversation(
    String userId,
    String epoch,
    String id,
  ) async {
    final row = await db
        .customSelect(
          'SELECT c.conversation_id FROM conversation c JOIN user_profile u ON u.user_id = c.user_id WHERE c.conversation_id = ? AND c.user_id = ? AND u.account_epoch = ?',
          variables: [
            Variable.withString(id),
            Variable.withString(userId),
            Variable.withString(epoch),
          ],
        )
        .getSingleOrNull();
    if (row == null) {
      throw const ChatPersistenceFailure(
        ChatPersistenceFailureCode.conversationMissing,
      );
    }
  }

  static void _checkRequest(bool Function()? current) {
    if (current != null && !current()) {
      throw const ChatPersistenceFailure(
        ChatPersistenceFailureCode.requestCancelled,
      );
    }
  }

  /// Drift needs table annotations on custom SQL writers to notify this watch.
  Stream<bool> watchSession({
    required String userId,
    required String accountEpoch,
    required Uint8List sessionNonceHash,
    String? conversationId,
  }) => db
      .customSelect(
        '''
    SELECT EXISTS(SELECT 1 FROM user_profile u
      WHERE u.user_id = ? AND u.account_epoch = ? AND u.active_session_nonce_hash = ?
      ${conversationId == null ? '' : 'AND EXISTS(SELECT 1 FROM conversation c WHERE c.user_id = u.user_id AND c.conversation_id = ?)'}
    ) AS valid
  ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(accountEpoch),
          Variable.withBlob(sessionNonceHash),
          if (conversationId != null) Variable.withString(conversationId),
        ],
        readsFrom: {db.userProfile, db.conversation},
      )
      .watch()
      .map((rows) => rows.single.read<int>('valid') == 1)
      .distinct();
}
