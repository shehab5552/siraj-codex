import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/conversation_repository.dart';
import '../../integrations/ai/tutor_contract.dart';
import '../../integrations/ai/tutor_port.dart';
import '../auth/auth_models.dart';
import '../auth/session_guard.dart';
import 'chat_models.dart';
import 'conversation_draft_controller.dart';

export 'chat_models.dart';

/// B-08 application boundary. Widgets never perform persistence or Tutor work.
/// A owns the actual retrieval/evidence/model implementation behind TutorPort.
class ChatTurnCoordinator extends ChangeNotifier {
  ChatTurnCoordinator({
    required this.session,
    required ConversationRepository conversations,
    required SessionGuard guard,
    TutorPort tutor = const UnavailableTutorPort(),
    SourceResolverPort sources = const UnavailableSourceResolver(),
    String? conversationId,
    ConversationDraftController? draft,
    String Function()? newId,
    DateTime Function()? clock,
  }) : _conversations = conversations,
       _guard = guard,
       _tutor = tutor,
       _sources = sources,
       _conversationId = conversationId ?? draft?.conversationId,
       _newId = newId ?? Uuid().v4,
       _clock = clock ?? DateTime.now,
       _draft =
           draft ??
           ConversationDraftController(
             conversations: conversations,
             guard: guard,
             newId: newId,
             clock: clock,
           );

  factory ChatTurnCoordinator.fromDraft(
    ConversationDraftController draft,
    AuthSession session, {
    TutorPort tutor = const UnavailableTutorPort(),
    SourceResolverPort sources = const UnavailableSourceResolver(),
  }) => ChatTurnCoordinator(
    session: session,
    conversations: draft.repository,
    guard: draft.sessionGuard,
    draft: draft,
    tutor: tutor,
    sources: sources,
  );

  final AuthSession session;
  final ConversationRepository _conversations;
  final SessionGuard _guard;
  final TutorPort _tutor;
  final SourceResolverPort _sources;
  final ConversationDraftController _draft;
  final String Function() _newId;
  final DateTime Function() _clock;
  String? _conversationId;
  List<ChatMessage> _messages = const [];
  ChatPhase _phase = ChatPhase.loading;
  ChatFailure? _failure;
  TutorResult? _lastResult;
  Future<void>? _initialization;
  Future<void>? _worker;
  StreamSubscription<bool>? _watch;
  late Uint8List _nonceHash;
  _ChatTurn? _active;
  _ChatTurn? _retryTurn;
  var _closed = false;
  var _viewVersion = 0;
  var _watchVersion = 0;
  var _lastUserSaved = false;
  var _evictionNoticePending = false;

  String? get conversationId => _conversationId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatPhase get phase => _phase;
  ChatFailure? get failure => _failure;
  TutorResult? get lastResult => _lastResult;
  bool get isBusy => _active != null || _phase == ChatPhase.loading;
  bool get canSend => !_closed && !isBusy && _phase != ChatPhase.sessionExpired;
  bool get canRetry => canSend && _retryTurn != null;
  bool get lastUserMessageSaved => _lastUserSaved;
  TutorAvailability get availability => _tutor.availability;
  String get _utc => _clock().toUtc().toIso8601String();

  bool takeEvictionNotice() {
    final pending = _evictionNoticePending;
    _evictionNoticePending = false;
    return pending;
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _nonceHash = Uint8List.fromList(
        (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
      );
      if (_closed) return;
      if (!await _guard.isCurrent(session)) {
        _expire();
        return;
      }
      if (_closed) return;
      _subscribe();
      if (!await _refresh()) return;
      if (_active == null) _phase = ChatPhase.ready;
      // A reopened USER without a reply can be retried without re-insertion.
      if (_active == null && _messages.isNotEmpty && _messages.last.isUser) {
        final last = _messages.last;
        _retryTurn = _ChatTurn(
          question: last.text,
          requestId: '',
          userMessageId: last.id,
          userSaved: true,
        );
        _failure = const ChatFailure(ChatFailureCode.unansweredMessage);
      }
      _notify();
    } catch (_) {
      if (!_closed && _phase != ChatPhase.sessionExpired) {
        _messages = const [];
        _failure = const ChatFailure(ChatFailureCode.persistenceFailure);
        _phase = ChatPhase.failed;
        _notify();
      }
    }
  }

  void _subscribe() {
    final version = ++_watchVersion;
    unawaited(_watch?.cancel());
    _watch = _conversations
        .watchSession(
          userId: session.userId,
          accountEpoch: session.accountEpoch,
          sessionNonceHash: _nonceHash,
          conversationId: _conversationId,
        )
        .listen(
          (valid) {
            if (!_closed && version == _watchVersion && !valid) _expire();
          },
          onError: (Object error, StackTrace stack) {
            if (!_closed && version == _watchVersion) {
              _expire(const ChatFailure(ChatFailureCode.persistenceFailure));
            }
          },
        );
  }

  Future<bool> _refresh() async {
    final version = ++_viewVersion;
    final id = _conversationId;
    final rows = id == null
        ? null
        : await _conversations.listMessages(
            userId: session.userId,
            accountEpoch: session.accountEpoch,
            conversationId: id,
            sessionNonceHash: _nonceHash,
          );
    if (_closed ||
        version != _viewVersion ||
        _phase == ChatPhase.sessionExpired) {
      return false;
    }
    if (!await _guard.isCurrent(session)) {
      _expire();
      return false;
    }
    if (_closed ||
        version != _viewVersion ||
        _phase == ChatPhase.sessionExpired) {
      return false;
    }
    _messages = rows == null
        ? const []
        : rows.map(ChatMessage.fromRow).toList();
    return true;
  }

  Future<void> refresh() async {
    await initialize();
    if (_closed || _phase == ChatPhase.sessionExpired) return;
    // A turn owns its post-write reads. A presentation-only lifecycle refresh
    // must not supersede them and silently stop saved work before Tutor runs.
    // Live session invalidation remains active throughout the turn.
    if (_active != null) return;
    try {
      if (await _refresh()) _notify();
    } on ChatPersistenceFailure {
      _expire(const ChatFailure(ChatFailureCode.conversationMissing));
    } catch (_) {
      _expire(const ChatFailure(ChatFailureCode.persistenceFailure));
    }
  }

  Future<void> send(String question) {
    final trimmed = question.trim();
    if (_closed || _phase == ChatPhase.sessionExpired) return Future.value();
    if (_active != null) {
      return trimmed == _active!.question ? _worker! : Future.value();
    }
    if (trimmed.isEmpty) {
      _failure = const ChatFailure(ChatFailureCode.invalidQuestion);
      _notify();
      return Future.value();
    }
    return _start(_ChatTurn(question: trimmed, requestId: _newId()));
  }

  Future<void> retry() {
    if (_active != null) return _worker!;
    final previous = _retryTurn;
    if (_closed || _phase == ChatPhase.sessionExpired || previous == null) {
      return Future.value();
    }
    return _start(
      _ChatTurn(
        question: previous.question,
        requestId: _newId(),
        userMessageId: previous.userMessageId,
        userSaved: previous.userSaved,
      ),
    );
  }

  Future<void> _start(_ChatTurn turn) {
    _active = turn;
    _retryTurn = turn;
    _lastUserSaved = turn.userSaved;
    _failure = null;
    _lastResult = null;
    _phase = ChatPhase.saving;
    // _run yields at initialize before listeners can re-enter send().
    _worker = _run(turn);
    _notify();
    return _worker!;
  }

  bool _current(_ChatTurn turn) =>
      !_closed &&
      identical(_active, turn) &&
      !turn.cancellation.isCancelled &&
      _phase != ChatPhase.sessionExpired;

  Future<void> _run(_ChatTurn turn) async {
    try {
      await initialize();
      if (!_current(turn)) return;
      if (!await _guard.isCurrent(session)) {
        _expire();
        return;
      }
      if (!_current(turn)) return;
      if (!turn.userSaved) {
        if (_conversationId == null) {
          _conversationId = await _draft.commitFirstQuestion(
            session: session,
            question: turn.question,
            isRequestCurrent: () => _current(turn),
          );
          turn.userMessageId = _draft.firstMessageId;
          _evictionNoticePending =
              _draft.evictedOldest &&
              !_closed &&
              _phase != ChatPhase.sessionExpired;
          _subscribe();
        } else {
          turn.userMessageId ??= _newId();
          await _conversations.appendUserMessage(
            userId: session.userId,
            accountEpoch: session.accountEpoch,
            conversationId: _conversationId!,
            messageId: turn.userMessageId!,
            question: turn.question,
            nowUtc: _utc,
            sessionNonceHash: _nonceHash,
            isRequestCurrent: () => _current(turn),
          );
        }
        turn.userSaved = true;
      }
      _lastUserSaved = true;
      _retryTurn = turn;
      if (!_current(turn) || !await _refresh() || !_current(turn)) return;
      // SQLite may have committed even if the caller lost its acknowledgement.
      // Recover that exact durable reply instead of generating/inserting again.
      final storedReply = _messages.where(
        (message) =>
            message.id == '${turn.userMessageId}:assistant' && !message.isUser,
      );
      if (storedReply.isNotEmpty) {
        _retryTurn = null;
        _failure = storedReply.first.sourcesUnavailable
            ? const ChatFailure(ChatFailureCode.sourceUnavailable)
            : null;
        _phase = _failure == null ? ChatPhase.ready : ChatPhase.failed;
        return;
      }
      // A reconstructed retry is valid only while its exact USER remains last.
      if (_messages.isEmpty ||
          _messages.last.id != turn.userMessageId ||
          !_messages.last.isUser ||
          _messages.last.text != turn.question) {
        throw const ChatPersistenceFailure(
          ChatPersistenceFailureCode.messageConflict,
        );
      }
      _phase = ChatPhase.asking;
      _notify();
      final available = _tutor.availability;
      if (!available.isReady) {
        _lastResult = TutorResult.error(
          available.error ?? TutorErrorCode.resourceNotReady,
        );
        _failure = ChatFailure(
          ChatFailureCode.tutorFailure,
          tutorError: _lastResult!.error,
        );
        _phase = ChatPhase.failed;
        return;
      }
      final request = TutorRequest(
        requestId: turn.requestId,
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        conversationId: _conversationId!,
        question: turn.question,
        datasetRevision: available.datasetRevision,
        cancellation: turn.cancellation,
        history: [
          for (final message in _messages)
            if (message.id != turn.userMessageId)
              TutorContextMessage(
                role: message.isUser ? 'USER' : 'ASSISTANT',
                text: message.text,
              ),
        ],
      );
      final response = await Future.any<TutorReply?>([
        Future.sync(() => _tutor.ask(request)),
        turn.cancellation.whenCancelled.then<TutorReply?>((_) => null),
      ]);
      if (!_current(turn) || response == null) return;
      if (!await _guard.isCurrent(session)) {
        _expire();
        return;
      }
      if (!_current(turn)) return;
      final result = response.checkedFor(request);
      if (result.status == TutorStatus.error) {
        _lastResult = result;
        _failure = ChatFailure(
          ChatFailureCode.tutorFailure,
          tutorError: result.error,
        );
        _phase = ChatPhase.failed;
        return;
      }
      final text = switch (result.status) {
        TutorStatus.answer =>
          result.isPartial
              ? 'إجابة جزئية: توجد أجزاء من الطلب لا تدعمها الأدلة المتاحة.\n${result.text!.trim()}'
              : result.text!.trim(),
        TutorStatus.refusal =>
          result.reason == TutorReason.needsScopeClarification
              ? 'أحتاج توضيح السؤال لتحديد نطاقه قبل الإجابة.'
              : 'لا تتوفر أدلة كافية للإجابة عن هذا السؤال.',
        TutorStatus.error => throw StateError(
          'Error cannot become an assistant message',
        ),
      };
      _phase = ChatPhase.saving;
      _notify();
      await _conversations.appendAssistantMessage(
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        conversationId: _conversationId!,
        messageId: '${turn.userMessageId}:assistant',
        answer: text,
        sourceRefsJson: jsonEncode(
          result.sources.map((ref) => ref.toJson()).toList(),
        ),
        nowUtc: _utc,
        sessionNonceHash: _nonceHash,
        isRequestCurrent: () => _current(turn),
        inReplyToMessageId: turn.userMessageId,
      );
      if (!_current(turn) || !await _refresh() || !_current(turn)) return;
      _retryTurn = null;
      _lastResult = result;
      _failure = null;
      _phase = ChatPhase.ready;
    } on TutorContractFailure {
      if (_current(turn)) {
        _failure = const ChatFailure(ChatFailureCode.invalidResponse);
        _phase = ChatPhase.failed;
      }
    } on ChatPersistenceFailure catch (error) {
      if (_closed || _phase == ChatPhase.sessionExpired) return;
      switch (error.code) {
        case ChatPersistenceFailureCode.sessionExpired:
          _expire();
        case ChatPersistenceFailureCode.conversationMissing:
          _expire(const ChatFailure(ChatFailureCode.conversationMissing));
        case ChatPersistenceFailureCode.requestCancelled:
          break;
        case ChatPersistenceFailureCode.messageConflict:
          _failure = const ChatFailure(ChatFailureCode.persistenceFailure);
          _phase = ChatPhase.failed;
      }
    } on AuthFailure {
      _expire();
    } catch (_) {
      if (_current(turn)) {
        _failure = _phase == ChatPhase.asking
            ? const ChatFailure(
                ChatFailureCode.tutorFailure,
                tutorError: TutorErrorCode.generationFailed,
              )
            : const ChatFailure(ChatFailureCode.persistenceFailure);
        _phase = ChatPhase.failed;
      }
    } finally {
      if (identical(_active, turn)) {
        if (!_closed &&
            _phase != ChatPhase.sessionExpired &&
            turn.cancellation.isCancelled) {
          if (turn.userSaved) {
            try {
              await _refresh();
            } catch (_) {
              _messages = const [];
            }
          }
          // Session invalidation may arrive while the cancellation refresh is
          // awaiting SQLite. Never overwrite that terminal privacy boundary.
          if (!_closed && _phase != ChatPhase.sessionExpired) {
            _lastResult = null;
            final committed = _messages.any(
              (message) =>
                  message.id == '${turn.userMessageId}:assistant' &&
                  !message.isUser,
            );
            if (committed) {
              // Cancellation cannot undo a reply committed before its request.
              _retryTurn = null;
              _phase = ChatPhase.ready;
              _failure = null;
            } else {
              _phase = ChatPhase.cancelled;
              _failure = const ChatFailure(ChatFailureCode.requestCancelled);
            }
          }
        }
        _active = null;
        _worker = null;
        _notify();
      }
    }
  }

  Future<void> cancel() async {
    final turn = _active;
    if (turn == null) return;
    turn.cancellation.cancel();
    _cancelAdapter(turn.requestId);
    await _worker;
  }

  void _cancelAdapter(String requestId) {
    unawaited(
      Future.sync(() => _tutor.cancel(requestId)).catchError((Object _) {
        /* Late callbacks are fenced even if native cancellation fails. */
      }),
    );
  }

  void _expire([
    ChatFailure failure = const ChatFailure(ChatFailureCode.sessionExpired),
  ]) {
    if (_closed) return;
    ++_viewVersion;
    _phase = ChatPhase.sessionExpired;
    _failure = failure;
    _messages = const [];
    _lastUserSaved = false;
    _lastResult = null;
    _retryTurn = null;
    _evictionNoticePending = false;
    final turn = _active;
    if (turn != null) {
      turn.cancellation.cancel();
      _cancelAdapter(turn.requestId);
    }
    _notify();
  }

  Future<ResolvedSource?> resolveSource(SourceReference reference) async {
    await initialize();
    final version = _viewVersion;
    if (_closed ||
        _phase == ChatPhase.sessionExpired ||
        !reference.isValid ||
        !_messages.any((message) => message.sources.contains(reference))) {
      return null;
    }
    try {
      if (!await _guard.isCurrent(session)) {
        _expire();
        return null;
      }
      final source = await _sources.resolve(reference);
      if (_closed ||
          version != _viewVersion ||
          _phase == ChatPhase.sessionExpired) {
        return null;
      }
      if (!await _guard.isCurrent(session)) {
        _expire();
        return null;
      }
      if (_closed ||
          version != _viewVersion ||
          source == null ||
          source.reference != reference ||
          source.snippet.trim().isEmpty ||
          (source.page != null && source.page! <= 0)) {
        return null;
      }
      return source;
    } catch (_) {
      return null;
    }
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    ++_viewVersion;
    ++_watchVersion;
    final turn = _active;
    if (turn != null) {
      turn.cancellation.cancel();
      _cancelAdapter(turn.requestId);
    }
    unawaited(_watch?.cancel());
    super.dispose();
  }
}

class _ChatTurn {
  _ChatTurn({
    required this.question,
    required this.requestId,
    this.userMessageId,
    this.userSaved = false,
  });
  final String question;
  final String requestId;
  String? userMessageId;
  bool userSaved;
  final cancellation = TutorCancellation();
}
