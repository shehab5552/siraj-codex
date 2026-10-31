import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../data/conversation_repository.dart';
import '../auth/auth_models.dart';
import '../auth/session_guard.dart';

/// B-05: the "New conversation" draft lives only in memory.
/// No DB row exists until a non-blank first user message passes a session
/// check and is committed by the B-03 atomic repository operation.
///
/// One controller instance represents one draft. The UI must never treat
/// the returned ID as an AI reply or start a Tutor call without the later
/// verified integration contracts.
class ConversationDraftController {
  ConversationDraftController({
    required ConversationRepository conversations,
    required SessionGuard guard,
    String Function()? newId,
    DateTime Function()? clock,
  }) : _conversations = conversations,
       _guard = guard,
       _newId = newId ?? Uuid().v4,
       _clock = clock ?? DateTime.now;

  final ConversationRepository _conversations;
  final SessionGuard _guard;
  final String Function() _newId;
  final DateTime Function() _clock;

  Future<String>? _pendingCommit;
  String? _conversationId;
  String? _firstQuestion;
  String? _draftId;
  String? _firstMessageId;
  bool _evictedOldest = false;

  String? get conversationId => _conversationId;
  String? get firstMessageId => _firstMessageId;
  bool get evictedOldest => _evictedOldest;
  ConversationRepository get repository => _conversations;
  SessionGuard get sessionGuard => _guard;
  bool get isTemporary => _conversationId == null;

  /// Returns the new conversation ID. Concurrent duplicate calls share
  /// the same operation, so rapid taps cannot create multiple chats.
  Future<String> commitFirstQuestion({
    required AuthSession session,
    required String question,
    bool Function()? isRequestCurrent,
  }) {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      return Future<String>.error(
        ArgumentError.value(question, 'question', 'Question is blank'),
      );
    }

    final completed = _conversationId;
    if (completed != null) {
      if (trimmed == _firstQuestion) return Future<String>.value(completed);
      return Future<String>.error(
        StateError('First message already committed for this draft'),
      );
    }
    final pending = _pendingCommit;
    if (pending != null) return pending;

    late final Future<String> operation;
    operation = _commit(session, trimmed, isRequestCurrent).whenComplete(() {
      if (identical(_pendingCommit, operation)) _pendingCommit = null;
    });
    _pendingCommit = operation;
    return operation;
  }

  Future<String> _commit(
    AuthSession session,
    String question,
    bool Function()? isRequestCurrent,
  ) async {
    if (!await _guard.isCurrent(session)) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    final conversationId = _draftId ??= _newId();
    final messageId = _firstMessageId ??= _newId();
    final nonceHash = await Sha256().hash(utf8.encode(session.sessionNonce));
    final committed = await _conversations.saveFirstUserMessageWithOutcome(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      conversationId: conversationId,
      messageId: messageId,
      question: question,
      nowUtc: _clock().toUtc().toIso8601String(),
      sessionNonceHash: Uint8List.fromList(nonceHash.bytes),
      isRequestCurrent: isRequestCurrent,
    );
    _evictedOldest = committed.evictedOldest;
    _firstQuestion = question;
    _conversationId = conversationId;
    return conversationId;
  }
}
