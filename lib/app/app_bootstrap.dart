import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/conversation_repository.dart';
import '../data/database_runtime.dart';
import '../data/user_repository.dart';
import '../features/auth/login_page.dart';
import '../features/auth/session_guard.dart';
import '../features/auth/signup_page.dart';
import '../features/auth/session_marker_store.dart';
import '../features/auth/startup_session_resolver.dart';
import '../features/chat/conversation_draft_controller.dart';
import '../features/home/home_page.dart';
import 'app_routes.dart';

/// B-06 Step 1: fail-closed startup. No test-only/weak KDF is connected.
/// Debug preview is an explicit opt-in used only by the legacy widget tests.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.debugPreview = false,
    this.loadStartupForTesting,
  });

  final bool debugPreview;
  final Future<StartupDecision> Function()? loadStartupForTesting;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  DatabaseRuntime? _runtime;
  late Future<StartupDecision> _startup;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
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
              onOpenChat: () {
                final users = UserRepository(runtime.database);
                Navigator.of(context).pushNamed(
                  AppRoutes.chat,
                  arguments: AuthenticatedChatRoute(
                    session: session,
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
