import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/login_page.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/session_marker_store.dart';
import 'package:siraj/features/auth/signup_page.dart';

/// Separate test entry point. Never wired to lib/main.dart or AppBootstrap.
/// Install ONLY after checking the separate APK application ID in the guide.
void main() {
  if (!kDebugMode || !Platform.isAndroid) {
    throw UnsupportedError(
      'B-04 probe requires an isolated Android debug build',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.forTesting(driftDatabase(name: 'siraj_b04_probe'));
  final users = UserRepository(db);
  final kdf = Stopwatch();
  final auth = AuthService(
    users: users,
    passwordHasher: PasswordHasher(
      iterations: PasswordHasher.candidateIterations,
    ),
    markerStore: const KeystoreSessionMarkerStore.forTesting(),
    onDiagnosticStep: (step) {
      if (step == 'signup.kdf_started') kdf.reset();
      if (step == 'signup.kdf_started') kdf.start();
      if (step == 'signup.kdf_passed') {
        kdf.stop();
        debugPrint('SIRAJ_B04_METRIC signup_kdf_ms=${kdf.elapsedMilliseconds}');
      }
      debugPrint('SIRAJ_B04_CORE step=$step');
    },
  );
  runApp(B04ProbeApp(auth: auth, users: users));
}

/// Test-only UI around existing production contracts. No fake credentials or
/// fake storage are constructed here. The DB survives force-stop/reboot.
class B04ProbeApp extends StatefulWidget {
  const B04ProbeApp({super.key, required this.auth, required this.users});
  final AuthService auth;
  final UserRepository users;
  @override
  State<B04ProbeApp> createState() => _B04ProbeAppState();
}

class _B04ProbeAppState extends State<B04ProbeApp> {
  bool _ready = false;
  bool _busy = true;
  bool _accountExists = false;
  int _resources = 0;
  String? _error;
  Future<void> Function()? _retry;

  @override
  void initState() {
    super.initState();
    _run(_restore);
  }

  @override
  void dispose() {
    widget.auth.cancelPendingAuthentication();
    super.dispose();
  }

  Future<void> _restore() async {
    await widget.auth.restoreSession();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final account = await widget.users.currentAccount();
      final row = await widget.users.db
          .customSelect('SELECT COUNT(*) AS n FROM installed_resource')
          .getSingle();
      if (!mounted) return;
      setState(() {
        _accountExists = account != null;
        _resources = row.read<int>('n');
        _ready = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is AuthFailure
              ? e.code.name
              : 'storage_or_platform_failure';
          _retry = action;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login({
    required String username,
    required String password,
  }) async {
    final watch = Stopwatch()..start();
    try {
      await widget.auth.login(username: username, password: password);
    } finally {
      debugPrint(
        'SIRAJ_B04_METRIC login_total_ms=${watch.elapsedMilliseconds}',
      );
    }
  }

  void _authenticated() {
    if (mounted) setState(() => _accountExists = true);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف حساب الاختبار؟'),
        content: const Text(
          'تحذف بيانات حساب الاختبار فقط. تبقى سجلات الموارد المشتركة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            key: const Key('probe-confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() => widget.auth.deleteCurrentAccount(confirmed: true));
    }
  }

  Future<void> _addFixture() async {
    final session = widget.auth.activeSession;
    if (session == null || !await widget.auth.checkSession(session)) {
      throw const AuthFailure(AuthFailureCode.sessionInvalid);
    }
    await widget.users.db.customStatement(
      "INSERT OR IGNORE INTO installed_resource(resource_id,kind,state,updated_at) VALUES ('b04-probe-shared','PDF','MISSING','2026-10-23T00:00:00Z')",
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SIRAJ B-04 isolated probe',
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('B-04 — اختبار معزول، غير إنتاجي')),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '600000 مرشح للاختبار؛ لا اعتماد إنتاجي. استخدم بيانات اختبار فقط.',
              ),
            ),
            Text(
              'سجلات الموارد المشتركة: $_resources',
              key: const Key('probe-resource-count'),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_busy) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_error != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'فشل آمن: $_error',
                            key: const Key('probe-error'),
                          ),
                          TextButton(
                            key: const Key('probe-retry'),
                            onPressed: () => _run(_retry!),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!_ready) return const SizedBox.shrink();
                  if (widget.auth.activeSession != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'جلسة اختبار نشطة',
                            key: Key('probe-session'),
                          ),
                          TextButton(
                            key: const Key('probe-logout'),
                            onPressed: () => _run(widget.auth.logout),
                            child: const Text('تسجيل الخروج'),
                          ),
                          TextButton(
                            key: const Key('probe-delete'),
                            onPressed: () => _delete(context),
                            child: const Text('حذف حساب الاختبار'),
                          ),
                          TextButton(
                            onPressed: () => _run(_addFixture),
                            child: const Text('إضافة سجل مورد اختبار MISSING'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (_accountExists) {
                    return LoginPage(
                      onLogin: _login,
                      onCancel: widget.auth.cancelPendingAuthentication,
                      onCompleted: _authenticated,
                    );
                  }
                  return SignupPage(
                    onCreateAccount:
                        ({
                          required username,
                          required password,
                          required confirmation,
                        }) async {
                          await widget.auth.createAccount(
                            username: username,
                            password: password,
                            confirmation: confirmation,
                          );
                        },
                    onLoginAfterCreation: _login,
                    onCancel: widget.auth.cancelPendingAuthentication,
                    onCompleted: _authenticated,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
