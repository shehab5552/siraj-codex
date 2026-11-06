import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../../data/conversation_repository.dart';
import '../auth/auth_models.dart';
import '../auth/session_guard.dart';
import 'conversation_draft_controller.dart';
import 'tutor_contracts.dart';

class ChatTurnOutcome {
  const ChatTurnOutcome(this.conversationId, this.result);
  final String conversationId;
  final TutorResult result;
}

/// Application boundary: USER commit precedes Tutor; only validated current
/// answers can reach SQLite. One coordinator owns one saved conversation.
class ChatTurnCoordinator {
  ChatTurnCoordinator({
    required this.draft,
    required this.conversations,
    required this.guard,
    required this.tutor,
    DateTime Function()? clock,
    Future<void> Function()? onDispose,
  }) : _clock = clock ?? DateTime.now,
       _onDispose = onDispose;
  final ConversationDraftController draft;
  final ConversationRepository conversations;
  final SessionGuard guard;
  final TutorPort tutor;
  final DateTime Function() _clock;
  final Future<void> Function()? _onDispose;
  TutorCancellation? _active;
  bool _disposed = false;
  String? _firstTurnId;
  String? _firstQuestion;
  String? get conversationId => draft.conversationId;
  void cancel() {
    _active?.cancel();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancel();
    final close = _onDispose;
    if (close != null) unawaited(close());
  }

  Future<ChatTurnOutcome> send({
    required AuthSession session,
    required String question,
    required String turnId,
  }) async {
    if (_disposed || _active != null) throw StateError('Chat turn unavailable');
    if (turnId.trim().isEmpty || question.trim().isEmpty) {
      throw ArgumentError('Invalid turn');
    }
    final token = TutorCancellation();
    _active = token;
    try {
      if (!await guard.isCurrent(session)) {
        throw const AuthFailure(AuthFailureCode.sessionInvalid);
      }
      final hash = Uint8List.fromList(
        (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
      );
      if (draft.conversationId == null) {
        await draft.commitFirstQuestion(session: session, question: question);
        _firstTurnId = turnId;
        _firstQuestion = question.trim();
      } else if (_firstTurnId == turnId) {
        if (_firstQuestion != question.trim()) {
          throw StateError('Turn payload conflict');
        }
      } else {
        await conversations.saveUserFollowUp(
          userId: session.userId,
          accountEpoch: session.accountEpoch,
          expectedNonceHash: hash,
          conversationId: draft.conversationId!,
          messageId: '$turnId-user',
          question: question,
          nowUtc: _clock().toUtc().toIso8601String(),
        );
      }
      final id = draft.conversationId!;
      ChatTurnOutcome outcome(TutorResult result) =>
          ChatTurnOutcome(id, result);
      if (token.isCancelled) {
        return outcome(TutorResult.error(TutorReason.cancelled));
      }
      TutorResult result;
      try {
        result = await tutor.ask(question, token);
      } on Exception {
        return outcome(TutorResult.error(TutorReason.generationFailed));
      }
      if (token.isCancelled || _disposed) {
        return outcome(TutorResult.error(TutorReason.cancelled));
      }
      if (!await guard.isCurrent(session)) {
        return outcome(TutorResult.error(TutorReason.sessionInvalid));
      }
      if (result.status != TutorStatus.answer) return outcome(result);
      if (result.sources.isEmpty ||
          result.sources.any(
            (s) => !tutor.isRevisionCurrent(s.datasetRevision),
          )) {
        return outcome(TutorResult.error(TutorReason.sourceUnavailable));
      }
      try {
        await conversations.appendAssistantMessage(
          userId: session.userId,
          accountEpoch: session.accountEpoch,
          expectedNonceHash: hash,
          conversationId: id,
          messageId: '$turnId-assistant',
          answer: result.text,
          sourceRefsJson: jsonEncode(
            result.sources.map((s) => s.toJson()).toList(),
          ),
          nowUtc: _clock().toUtc().toIso8601String(),
          isRequestCurrent: () =>
              !token.isCancelled &&
              !_disposed &&
              identical(_active, token) &&
              result.sources.every(
                (s) => tutor.isRevisionCurrent(s.datasetRevision),
              ),
        );
      } on StateError {
        return outcome(
          TutorResult.error(
            token.isCancelled
                ? TutorReason.cancelled
                : TutorReason.conversationUnavailable,
          ),
        );
      } on Exception {
        return outcome(TutorResult.error(TutorReason.persistenceFailure));
      }
      if (token.isCancelled || _disposed) {
        return outcome(TutorResult.error(TutorReason.cancelled));
      }
      return outcome(result);
    } finally {
      if (identical(_active, token)) _active = null;
    }
  }
}
