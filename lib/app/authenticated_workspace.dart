import 'dart:async';
import 'package:flutter/material.dart';
import '../data/conversation_repository.dart';
import '../data/resource_repository.dart';
import '../data/quiz_session_access.dart';
import '../data/user_repository.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/session_guard.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/conversation_history_controller.dart';
import '../features/chat/conversation_history_page.dart';
import '../features/home/siraj_main_shell.dart';
import '../features/library/library_page.dart';
import '../features/quiz/quiz_cleanup_owner.dart';
import '../features/quiz/quiz_controller.dart';
import '../features/quiz/quiz_page.dart';
import '../features/quiz/quiz_scorer.dart';
import '../features/resources/resource_status_page.dart';
import '../features/resources/resource_status_reader.dart';
import '../features/settings/settings_page.dart';
import '../integrations/ai/tutor_port.dart';
import '../integrations/ai/quiz_port.dart';
import 'app_session_controller.dart';

/// Authenticated composition scope. Feature widgets contain no SQLite wiring.
class AuthenticatedWorkspace extends StatefulWidget {
  const AuthenticatedWorkspace({
    super.key,
    required this.session,
    required this.identity,
    required this.tutor,
    required this.sources,
    required this.quiz,
    required this.numericPrecision,
    required this.quizCleanup,
  });
  final AppSessionController session;
  final AuthSession identity;
  final TutorPort tutor;
  final SourceResolverPort sources;
  final QuizPort quiz;
  final NumericPrecisionPort numericPrecision;
  final QuizCleanupOwner quizCleanup;
  @override
  State<AuthenticatedWorkspace> createState() => _AuthenticatedWorkspaceState();
}

class _AuthenticatedWorkspaceState extends State<AuthenticatedWorkspace> {
  late final ConversationHistoryController _history =
      ConversationHistoryController(
        session: widget.identity,
        conversations: ConversationRepository(widget.session.runtime.database),
        guard: SessionGuard(UserRepository(widget.session.runtime.database)),
        tutor: widget.tutor,
        sources: widget.sources,
      );
  late final QuizController _quiz = QuizController(
    session: widget.identity,
    access: SqliteQuizSessionAccess(
      database: widget.session.runtime.database,
      session: widget.identity,
    ),
    port: widget.quiz,
    sources: widget.sources,
    scorer: QuizScorer(precision: widget.numericPrecision),
    cleanup: widget.quizCleanup,
  );
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    unawaited(_history.load());
  }

  Future<void> _push(Widget Function() page) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await widget.session.checkSession(widget.identity) || !mounted) {
        return;
      }
      unawaited(Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => page())));
    } finally {
      _opening = false;
    }
  }

  void _resources() => unawaited(
    _push(
      () => ResourceStatusPage(
        reader: ResourceStatusReader(
          ResourceRepository(widget.session.runtime.database),
        ),
      ),
    ),
  );
  Future<void> _chat([String? id]) async {
    if (_opening) return;
    _opening = true;
    try {
      final chat = id == null
          ? await _history.openDraft()
          : await _history.openConversation(id);
      if (!mounted) {
        chat?.dispose();
        return;
      }
      if (chat != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => ChatPage(coordinator: chat)),
        );
      }
      if (mounted) await _history.load();
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _history,
    builder: (context, _) => SirajMainShell(
      onOpenChat: () => unawaited(_chat()),
      onOpenResources: _resources,
      onOpenHistory: () => unawaited(
        _push(
          () => ConversationHistoryPage(
            controller: ConversationHistoryController(
              session: widget.identity,
              conversations: ConversationRepository(
                widget.session.runtime.database,
              ),
              guard: SessionGuard(
                UserRepository(widget.session.runtime.database),
              ),
              tutor: widget.tutor,
              sources: widget.sources,
            ),
          ),
        ),
      ),
      onOpenSettings: () => unawaited(
        _push(
          () => SettingsPage(
            session: widget.session,
            onOpenResources: _resources,
          ),
        ),
      ),
      latestConversationTitle: _history.conversations.isEmpty
          ? null
          : _history.conversations.first.title,
      onOpenLatest: _history.conversations.isEmpty
          ? null
          : () => unawaited(_chat(_history.conversations.first.id)),
      assistantPage: ConversationHistoryPage(controller: _history),
      libraryPage: LibraryPage(onOpenResources: _resources),
      quizPage: QuizPage(controller: _quiz),
    ),
  );
}
