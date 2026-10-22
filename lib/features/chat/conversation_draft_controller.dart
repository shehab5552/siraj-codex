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

  String? get conversationId => _conversationId;
  bool get isTemporary => _conversationId == null;

  /// Returns the new conversation ID. Concurrent duplicate calls share
  /// the same operation, so rapid taps cannot create multiple chats.
  Future<String> commitFirstQuestion({
    required AuthSession session,
    required String question,
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
    operation = _commit(session, trimmed).whenComplete(() {
      if (identical(_pendingCommit, operation)) _pendingCommit = null;
    });
    _pendingCommit = operation;
    return operation;
  }

  Future<String> _commit(AuthSession session, String question) async {
    if (!await _guard.isCurrent(session)) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    final conversationId = _newId();
    final messageId = _newId();
    await _conversations.saveFirstUserMessage(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      conversationId: conversationId,
      messageId: messageId,
      question: question,
      nowUtc: _clock().toUtc().toIso8601String(),
      sessionNonceHash: Uint8List.fromList(
        (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
      ),
      isRequestCurrent: () => !_guard.isBlocked(session),
    );
    _firstQuestion = question;
    _conversationId = conversationId;
    return conversationId;
  }
}
