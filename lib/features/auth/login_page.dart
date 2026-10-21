import 'package:flutter/material.dart';

import 'auth_form_frame.dart';

/// Interface contract ONLY; the local AuthService is deliberately not wired
/// until the production password KDF passes its security gate.
typedef LoginAction =
    Future<void> Function({required String username, required String password});

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onLogin, this.onCompleted});

  final LoginAction? onLogin;
  final VoidCallback? onCompleted;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final action = widget.onLogin;
    if (action == null || _busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(username: _username.text.trim(), password: _password.text);
      if (!mounted) return;
      widget.onCompleted?.call();
    } catch (_) {
      // Intentionally generic to avoid exposing which credential was wrong.
      if (mounted) {
        setState(() => _error = 'تعذّر تسجيل الدخول. تحقق من بيانات الحساب.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onLogin != null && !_busy;
    return AuthFormFrame(
      title: 'تسجيل الدخول',
      description: 'استخدم حساب سراج المحلي المسجل على هذا الجهاز.',
      notice: widget.onLogin == null
          ? 'تسجيل الدخول غير مفعّل مؤقتًا حتى اعتماد حماية كلمة المرور الإنتاجية.'
          : 'الجلسة تُحفظ على هذا الجهاز بعد التحقق من بيانات الحساب.',
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('login-username'),
              controller: _username,
              enabled: enabled,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
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
              key: const Key('login-password'),
              controller: _password,
              enabled: enabled,
              obscureText: _hidePassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('login-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('login-submit'),
              onPressed: enabled ? _submit : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('تسجيل الدخول'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا تتوفر استعادة كلمة المرور أو إضافة حساب ثانٍ في SIRAJ P0.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
