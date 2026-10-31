import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../data/conversation_repository.dart';
import '../../integrations/ai/tutor_port.dart';
import '../auth/auth_models.dart';
import '../auth/session_guard.dart';
import 'chat_turn_coordinator.dart';

class ConversationHistoryController extends ChangeNotifier {
  ConversationHistoryController({
    required AuthSession session,
    required ConversationRepository conversations,
    required SessionGuard guard,
    TutorPort tutor = const UnavailableTutorPort(),
    SourceResolverPort sources = const UnavailableSourceResolver(),
  }) : _session = session,
       _conversations = conversations,
       _guard = guard,
       _tutor = tutor,
       _sources = sources;
  final AuthSession _session;
  final ConversationRepository _conversations;
  final SessionGuard _guard;
  final TutorPort _tutor;
  final SourceResolverPort _sources;
  List<ConversationSummary> _items = const [];
  bool _loading = true;
  bool _expired = false;
  bool _closed = false;
  int _generation = 0;
  ChatFailure? _failure;
  Future<void>? _pendingLoad;
  StreamSubscription<bool>? _watch;

  List<ConversationSummary> get conversations => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get sessionExpired => _expired;
  ChatFailure? get failure => _failure;

  Future<void> load() {
    if (_closed || _expired) return Future.value();
    if (_pendingLoad != null) return _pendingLoad!;
    _loading = true;
    _failure = null;
    _pendingLoad = _read().whenComplete(() {
      _pendingLoad = null;
    });
    _notify();
    return _pendingLoad!;
  }

  Future<void> _read() async {
    final generation = ++_generation;
    try {
      if (!await _guard.isCurrent(_session)) {
        _expire();
        return;
      }
      if (_closed || _expired) return;
      final nonceHash = Uint8List.fromList(
        (await Sha256().hash(utf8.encode(_session.sessionNonce))).bytes,
      );
      if (_closed || _expired) return;
      _watch ??= _conversations
          .watchSession(
            userId: _session.userId,
            accountEpoch: _session.accountEpoch,
            sessionNonceHash: nonceHash,
          )
          .listen(
            (valid) {
              if (!valid) _expire();
            },
            onError: (Object error, StackTrace stack) {
              _expire();
            },
          );
      final rows = await _conversations.listConversations(
        userId: _session.userId,
        accountEpoch: _session.accountEpoch,
        sessionNonceHash: nonceHash,
      );
      final items = <ConversationSummary>[];
      for (final row in rows) {
        final id = row.read<String>('conversation_id');
        items.add(
          ConversationSummary(
            id: id,
            title: row.read<String?>('first_question') ?? 'محادثة محفوظة',
            createdAt: row.read<String>('created_at'),
          ),
        );
      }
      if (_closed || _expired || generation != _generation) return;
      if (!await _guard.isCurrent(_session)) {
        _expire();
        return;
      }
      if (_closed || _expired || generation != _generation) return;
      _items = items;
    } catch (_) {
      if (!_closed && !_expired && generation == _generation) {
        _items = const [];
        _failure = const ChatFailure(ChatFailureCode.persistenceFailure);
      }
    } finally {
      if (!_closed && generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<ChatTurnCoordinator?> openDraft() => _open(null);

  Future<ChatTurnCoordinator?> openConversation(String id) async {
    await load();
    if (_closed || _expired) return null;
    if (!_items.any((item) => item.id == id)) {
      _failure = const ChatFailure(ChatFailureCode.conversationMissing);
      _notify();
      return null;
    }
    return _open(id);
  }

  Future<ChatTurnCoordinator?> _open(String? id) async {
    if (_closed || _expired) return null;
    try {
      if (!await _guard.isCurrent(_session)) {
        _expire();
        return null;
      }
      if (_closed || _expired) return null;
      final coordinator = ChatTurnCoordinator(
        session: _session,
        conversations: _conversations,
        guard: _guard,
        tutor: _tutor,
        sources: _sources,
        conversationId: id,
      );
      await coordinator.initialize();
      if (_closed || _expired || coordinator.phase != ChatPhase.ready) {
        coordinator.dispose();
        _failure = const ChatFailure(ChatFailureCode.conversationMissing);
        _notify();
        return null;
      }
      return coordinator;
    } catch (_) {
      if (!_closed && !_expired) {
        _failure = const ChatFailure(ChatFailureCode.persistenceFailure);
        _notify();
      }
      return null;
    }
  }

  void _expire() {
    if (_closed) return;
    ++_generation;
    _expired = true;
    _loading = false;
    _items = const [];
    _failure = const ChatFailure(ChatFailureCode.sessionExpired);
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    ++_generation;
    unawaited(_watch?.cancel());
    super.dispose();
  }
}
