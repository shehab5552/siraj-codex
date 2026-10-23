import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/conversation_repository.dart';
import '../data/database_runtime.dart';
import '../data/resource_repository.dart';
import '../data/user_repository.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_guard.dart';
import '../features/auth/signup_page.dart';
import '../features/auth/session_marker_store.dart';
import '../features/auth/startup_session_resolver.dart';
import '../features/chat/conversation_draft_controller.dart';
import '../features/chat/conversation_history_controller.dart';
import '../features/chat/conversation_history_page.dart';
import '../features/home/home_page.dart';
import '../features/resources/resource_status_page.dart';
import '../features/resources/resource_status_reader.dart';
import '../integrations/ai/tutor_port.dart';
import '../integrations/ai/quiz_port.dart';
import '../data/quiz_session_access.dart';
import '../features/quiz/quiz_controller.dart';
import '../features/quiz/quiz_cleanup_owner.dart';
import '../features/quiz/quiz_scorer.dart';
import '../features/quiz/quiz_page.dart';
import 'app_routes.dart';

/// B-06 Step 1: fail-closed startup. No test-only/weak KDF is connected.
/// Debug preview is an explicit opt-in used only by the legacy widget tests.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.debugPreview = false,
    this.loadStartupForTesting,
    this.tutor = const UnavailableTutorPort(),
    this.sources = const UnavailableSourceResolver(),
    this.quiz = const UnavailableQuizPort(),
    this.numericPrecision = const UnavailableNumericPrecision(),
  });

  final bool debugPreview;
  final Future<StartupDecision> Function()? loadStartupForTesting;
  final TutorPort tutor;
  final SourceResolverPort sources;
  final QuizPort quiz;
  final NumericPrecisionPort numericPrecision;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with WidgetsBindingObserver {
  final _quizCleanup = QuizCleanupOwner();
  DatabaseRuntime? _runtime;
  late Future<StartupDecision> _startup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startup = _resolve();
  }

  Future<StartupDecision> _resolve() async {
    if (widget.debugPreview && kDebugMode) {
      // This branch is not used for production or the normal debug launch.
      return const StartupDecision(StartupStatus.loginRequired);
    }
    final loader = widget.loadStartupForTesting;
    if (loader != null) return loader();
    final runtime = _runtime ??= DatabaseRuntime();
    final users = UserRepository(runtime.database);
    return StartupSessionResolver(
      users: users,
      markerStore: const KeystoreSessionMarkerStore(),
    ).resolve();
  }

  bool _openingResources = false;

  /// B-07: the resource registry is device-scoped, but entry from the app
  /// must still be protected by the active account/session gate. Re-resolve
  /// the encrypted session and its SQLite nonce before navigation.
  Future<void> _openResourceStatus(
    AuthSession expected,
    DatabaseRuntime runtime,
  ) async {
    if (_openingResources) return;
    _openingResources = true;
    try {
      final decision = await StartupSessionResolver(
        users: UserRepository(runtime.database),
        markerStore: const KeystoreSessionMarkerStore(),
      ).resolve();
      if (!mounted) return;
      final current = decision.session;
      if (decision.status != StartupStatus.authenticated ||
          current == null ||
          current.userId != expected.userId ||
          current.accountEpoch != expected.accountEpoch ||
          current.sessionNonce != expected.sessionNonce) {
        // Do not keep a stale authenticated home in the widget tree.
        setState(() => _startup = _resolve());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('انتهت صلاحية الجلسة. يلزم تسجيل الدخول.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ResourceStatusPage(
            reader: ResourceStatusReader(ResourceRepository(runtime.database)),
          ),
        ),
      );
    } catch (_) {
      // Fail closed: do not open the registry on a database/Keystore error.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر التحقق من الجلسة.')),
        );
      }
    } finally {
      _openingResources = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_quizCleanup.retry());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugPreview && kDebugMode) return const HomePage();
    return FutureBuilder<StartupDecision>(
      future: _startup,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _statusScreen(
            context,
            'تعذّر بدء سراج بأمان. لم يتم فتح الحساب أو المحادثات.',
          );
        }
        final decision = snapshot.data!;
        switch (decision.status) {
          case StartupStatus.authenticated:
            final session = decision.session;
            final runtime = _runtime;
            if (session == null || runtime == null) {
              return _statusScreen(context, 'تعذّر استعادة الجلسة بأمان.');
            }
            return HomePage(
              onOpenQuiz: () {
                final controller = QuizController(
                  session: session,
                  access: SqliteQuizSessionAccess(
                    database: runtime.database,
                    session: session,
                  ),
                  port: widget.quiz,
                  sources: widget.sources,
                  scorer: QuizScorer(precision: widget.numericPrecision),
                  cleanup: _quizCleanup,
                );
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => QuizPage(controller: controller),
                  ),
                );
              },
              onOpenHistory: () {
                final history = ConversationHistoryController(
                  session: session,
                  conversations: ConversationRepository(runtime.database),
                  guard: SessionGuard(UserRepository(runtime.database)),
                  tutor: widget.tutor,
                  sources: widget.sources,
                );
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ConversationHistoryPage(controller: history),
                  ),
                );
              },
              onOpenResources: () =>
                  unawaited(_openResourceStatus(session, runtime)),
              onOpenChat: () {
                final users = UserRepository(runtime.database);
                Navigator.of(context).pushNamed(
                  AppRoutes.chat,
                  arguments: AuthenticatedChatRoute(
                    session: session,
                    tutor: widget.tutor,
                    sources: widget.sources,
                    draftController: ConversationDraftController(
                      conversations: ConversationRepository(runtime.database),
                      guard: SessionGuard(users),
                    ),
                  ),
                );
              },
            );
          case StartupStatus.accountRequired:
            // Fail-closed UI: no KDF approved means no account write handler.
            return const SignupPage();
          case StartupStatus.loginRequired:
            // Fail-closed UI: no KDF approved means no password verify handler.
            return const LoginPage();
          case StartupStatus.databaseUnavailable:
            return _statusScreen(
              context,
              'تعذّر قراءة قاعدة البيانات المحلية. لم يُفتح الحساب.',
            );
          case StartupStatus.secureStorageUnavailable:
            return _statusScreen(
              context,
              'تعذّر التحقق من الجلسة المشفّرة. لن يتم الدخول تلقائيًا.',
            );
        }
      },
    );
  }

  Widget _statusScreen(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('سراج — بدء التشغيل')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 20),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text(
                  'B-06 — بوابة الجلسة. لن تُستخدم بيانات تجريبية للدخول.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
