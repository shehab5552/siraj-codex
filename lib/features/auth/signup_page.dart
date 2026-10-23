import 'package:flutter/material.dart';

import 'auth_form_frame.dart';
import 'auth_models.dart';
import 'login_page.dart';

/// Interface contract ONLY. Production code must connect this to an AuthService
/// whose KDF has passed a separate security and on-device performance gate.
typedef CreateAccountAction =
    Future<void> Function({
      required String username,
      required String password,
      required String confirmation,
    });

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    this.onCreateAccount,
    this.onCompleted,
    this.onCancel,
    this.onLoginAfterCreation,
  });

  /// Null intentionally means: no password input and no account creation.
  final CreateAccountAction? onCreateAccount;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;
  final LoginAction? onLoginAfterCreation;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;
  bool _accountStored = false;

  @override
  void dispose() {
    if (_busy) widget.onCancel?.call();
    _username.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final action = widget.onCreateAccount;
    if (action == null || _busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(
        username: _username.text.trim(),
        password: _password.text,
        confirmation: _confirmation.text,
      );
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      widget.onCompleted?.call();
    } on AuthFailure catch (failure) {
      if (mounted) {
        final requiresLogin =
            failure.accountCreated ||
            failure.code == AuthFailureCode.accountAlreadyExists;
        if (requiresLogin) {
          _password.clear();
          _confirmation.clear();
        }
        setState(() {
          _accountStored = requiresLogin;
          _error = 'تعذّر إنشاء الحساب. تحقق من البيانات وحاول مجددًا.';
        });
      }
    } catch (_) {
      // Do not surface platform details, hashes, account IDs or passwords.
      if (mounted) {
        setState(
          () => _error = 'تعذّر إنشاء الحساب. تحقق من البيانات وحاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accountStored) {
      return LoginPage(
        onLogin: widget.onLoginAfterCreation,
        onCompleted: widget.onCompleted,
        onCancel: widget.onCancel,
        notice: 'حُفظ الحساب، وتعذّر إكمال الجلسة. سجّل الدخول للمتابعة.',
      );
    }
    final enabled = widget.onCreateAccount != null && !_busy;
    return AuthFormFrame(
      title: 'إنشاء الحساب المحلي',
      description: 'حساب واحد على هذا الجهاز، دون إنترنت أو خادم للحسابات.',
      notice: widget.onCreateAccount == null
          ? 'واجهة إنشاء الحساب جاهزة، لكنها غير مفعّلة حتى اعتماد حماية كلمة المرور الإنتاجية.'
          : 'يُحفظ الحساب محليًا. لا تتوفر استعادة كلمة مرور منسية في P0.',
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('signup-username'),
              controller: _username,
              enabled: enabled,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'اسم المستخدم مطلوب'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('signup-password'),
              controller: _password,
              enabled: enabled,
              obscureText: _hidePassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hidePassword
                      ? 'إظهار كلمة المرور'
                      : 'إخفاء كلمة المرور',
                  onPressed: enabled
                      ? () => setState(() => _hidePassword = !_hidePassword)
                      : null,
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'كلمة المرور مطلوبة' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('signup-confirmation'),
              controller: _confirmation,
              enabled: enabled,
              obscureText: _hideConfirmation,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hideConfirmation
                      ? 'إظهار التأكيد'
                      : 'إخفاء التأكيد',
                  onPressed: enabled
                      ? () => setState(
                          () => _hideConfirmation = !_hideConfirmation,
                        )
                      : null,
                  icon: Icon(
                    _hideConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'تأكيد كلمة المرور مطلوب';
                }

                if (value != _password.text) {
                  return 'كلمتا المرور غير متطابقتين';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'احتفظ بكلمة المرور في مكان آمن؛ لا توجد آلية لاستعادتها في هذه النسخة.',
              style: TextStyle(fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('signup-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('signup-submit'),
              onPressed: enabled ? _submit : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إنشاء الحساب'),
              ),
            ),
            if (_busy && widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('إلغاء'),
              ),
          ],
        ),
      ),
    );
  }
}
