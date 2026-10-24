import '../features/settings/account_appearance.dart';
import '../features/library/library_contracts.dart';
import '../features/quiz/quiz_curriculum.dart';
import 'resource_preparation_binding.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/database_runtime.dart';
import '../features/auth/login_page.dart';
import '../features/auth/signup_page.dart';
import '../features/auth/session_marker_store.dart';
import '../features/auth/password_hasher.dart';
import '../features/auth/native_pbkdf2.dart';
import '../features/auth/startup_session_resolver.dart';
import '../features/home/home_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/quiz/quiz_cleanup_owner.dart';
import '../integrations/ai/tutor_port.dart';
import '../integrations/ai/quiz_port.dart';
import '../core/localization/siraj_copy.dart';
import 'app_preferences.dart';
import 'app_session_controller.dart';
import 'authenticated_workspace.dart';

/// One normal entry point, one database owner and one AuthService composition.
/// Release credential entry remains closed pending the approved device profile.
/// The isolated debug build exercises the real native 600k evaluation candidate.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.debugPreview = false,
    this.loadStartupForTesting,
    this.sessionController,
    this.resourcePreparation,
    this.curriculum = const UnavailableQuizCurriculum(),
    this.library = const LibraryIntegration(),
    this.tutor = const UnavailableTutorPort(),
    this.sources = const UnavailableSourceResolver(),
    this.quiz = const UnavailableQuizPort(),
    this.numericPrecision = const UnavailableNumericPrecision(),
  });
  final bool debugPreview;
  final Future<StartupDecision> Function()? loadStartupForTesting;
  final AppSessionController? sessionController;
  final ResourcePreparationBinding? resourcePreparation;
  final QuizCurriculumPort curriculum;
  final LibraryIntegration library;
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
  AppSessionController? _session;
  DatabaseRuntime? _ownedRuntime;
  Future<StartupDecision>? _testStartup;
  bool _initializationFailed = false;
  AppPreferencesController? _preferences;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.debugPreview && kDebugMode) return;
    if (widget.loadStartupForTesting case final loader?) {
      _testStartup = loader();
      return;
    }
    _session =
        widget.sessionController ??
        AppSessionController(
          runtime: _ownedRuntime = DatabaseRuntime(),
          markerStore: const KeystoreSessionMarkerStore(),
          passwordHasher: kDebugMode && Platform.isAndroid
              ? PasswordHasher(
                  iterations: PasswordHasher.candidateIterations,
                  worker: NativePbkdf2(),
                )
              : null,
        );
    _session!.addListener(_changed);
    unawaited(_initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preferences = AppPreferencesScope.maybeOf(context);
    _syncAppearance();
  }

  void _syncAppearance() {
    final preferences = _preferences, session = _session;
    if (preferences == null ||
        session == null ||
        !session.initialized ||
        widget.debugPreview) {
      return;
    }
    final decision = session.decision;
    final identity = (session.navigationIdentity, decision.status);
    final AccountAppearanceStore? store = switch (decision.status) {
      StartupStatus.authenticated =>
        decision.session == null
            ? null
            : SqliteAccountAppearance(
                database: session.runtime.database,
                session: decision.session!,
              ),
      StartupStatus.loginRequired => ReadOnlyCurrentAccountAppearance(
        session.runtime.database,
      ),
      _ => null,
    };
    unawaited(preferences.bindAccount(identity: identity, store: store));
  }

  Future<void> _initialize() async {
    try {
      await _session!.initialize();
    } catch (_) {
      _initializationFailed = true;
    }
    if (mounted) setState(() {});
  }

  void _changed() {
    _syncAppearance();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_quizCleanup.retry());
      if (_session?.busy == false) unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      await _session?.refresh();
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.removeListener(_changed);
    if (widget.sessionController == null) _session?.dispose();
    if (_ownedRuntime != null) unawaited(_ownedRuntime!.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.debugPreview && kDebugMode) return const HomePage();
    if (_testStartup != null) {
      return FutureBuilder<StartupDecision>(
        future: _testStartup,
        builder: (context, snapshot) => snapshot.hasData
            ? _screen(snapshot.data!)
            : snapshot.hasError
            ? _status(
                context.copy(
                  'تعذر بدء سراج بأمان.',
                  'Could not start SIRAJ safely.',
                ),
              )
            : _loading(),
      );
    }
    if (_initializationFailed) {
      return _status(
        context.copy(
          'تعذر فتح البيانات المحلية بأمان. أعد المحاولة.',
          'Could not safely open local data. Please retry.',
        ),
      );
    }
    final session = _session;
    if (session == null || !session.initialized) return _loading();
    return _screen(session.decision);
  }

  Widget _loading() => const Scaffold(
    body: SafeArea(child: Center(child: CircularProgressIndicator())),
  );
  Widget _screen(StartupDecision decision) {
    if (_preferences?.accountLoading == true) return _loading();
    final session = _session;
    switch (decision.status) {
      case StartupStatus.authenticated:
        if (session == null || decision.session == null) {
          return _status(
            context.copy(
              'تعذر استعادة الجلسة بأمان.',
              'Could not safely restore the session.',
            ),
          );
        }
        // Destroying this Navigator on revocation removes every private route,
        // including dialogs and sources, rather than leaving Settings over Login.
        return Navigator(
          key: ObjectKey(session.navigationIdentity),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => AuthenticatedWorkspace(
              resourcePreparation: widget.resourcePreparation,
              curriculum: widget.curriculum,
              library: widget.library,
              session: session,
              identity: decision.session!,
              tutor: widget.tutor,
              sources: widget.sources,
              quiz: widget.quiz,
              numericPrecision: widget.numericPrecision,
              quizCleanup: _quizCleanup,
            ),
          ),
        );
      case StartupStatus.accountRequired:
        final prefs = AppPreferencesScope.maybeOf(context);
        if (prefs != null && !prefs.loaded) return _loading();
        if (prefs != null && !prefs.value.onboardingComplete) {
          return OnboardingPage(onComplete: prefs.completeOnboarding);
        }
        return SignupPage(
          onCreateAccount: session?.canAuthenticate == true
              ? session!.createAccount
              : null,
          onLoginAfterCreation: session?.canAuthenticate == true
              ? session!.login
              : null,
          onCancel: session?.cancelPendingAuthentication,
        );
      case StartupStatus.loginRequired:
        return LoginPage(
          onLogin: session?.canAuthenticate == true ? session!.login : null,
          onCancel: session?.cancelPendingAuthentication,
          notice: session?.revocationFailed == true
              ? context.copy(
                  'تعذر إكمال إنهاء الجلسة. بقيت البيانات محمية؛ أعد الدخول للمحاولة.',
                  'Session revocation could not finish. Data remains protected; log in again to recover.',
                )
              : null,
        );
      case StartupStatus.databaseUnavailable:
        return _status(
          context.copy(
            'تعذر قراءة قاعدة البيانات المحلية. لم يُفتح الحساب.',
            'Could not read the local database. The account was not opened.',
          ),
        );
      case StartupStatus.secureStorageUnavailable:
        return _status(
          context.copy(
            'تعذر التحقق من الجلسة المشفرة. لم يُفتح الحساب.',
            'Could not verify the encrypted session. The account was not opened.',
          ),
        );
    }
  }

  Widget _status(String message) => Scaffold(
    appBar: AppBar(title: Text(context.tr('سراج'))),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(_refresh()),
                child: Text(context.tr('إعادة المحاولة')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
