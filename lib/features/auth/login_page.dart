import '../../core/localization/siraj_copy.dart';
import 'package:flutter/material.dart';

import 'auth_form_frame.dart';

/// Interface contract ONLY; the local AuthService is deliberately not wired
/// until the production password KDF passes its security gate.
typedef LoginAction =
    Future<void> Function({required String username, required String password});

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onLogin,
    this.onCompleted,
    this.onCancel,
    this.notice,
  });

  final LoginAction? onLogin;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;
  final String? notice;

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
    if (_busy) widget.onCancel?.call();
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
      _password.clear();
      widget.onCompleted?.call();
    } catch (_) {
      // Intentionally generic to avoid exposing which credential was wrong.
      if (mounted) {
        setState(
          () =>
              _error = context.tr('تعذّر تسجيل الدخول. تحقق من بيانات الحساب.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onLogin != null && !_busy;
    return AuthFormFrame(
      title: context.tr('تسجيل الدخول'),
      description: context.tr('استخدم حساب سراج المحلي المسجل على هذا الجهاز.'),
      notice:
          widget.notice ??
          (widget.onLogin == null
              ? context.tr(
                  'تسجيل الدخول غير مفعّل مؤقتًا حتى اعتماد حماية كلمة المرور الإنتاجية.',
                )
              : context.tr(
                  'الجلسة تُحفظ على هذا الجهاز بعد التحقق من بيانات الحساب.',
                )),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: Key('login-username'),
              controller: _username,
              enabled: enabled,
              autofillHints: [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('اسم المستخدم'),
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('اسم المستخدم مطلوب')
                  : null,
            ),
            SizedBox(height: 14),
            TextFormField(
              key: Key('login-password'),
              controller: _password,
              enabled: enabled,
              obscureText: _hidePassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: [AutofillHints.password],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.tr('كلمة المرور'),
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hidePassword
                      ? context.tr('إظهار كلمة المرور')
                      : context.tr('إخفاء كلمة المرور'),
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
              validator: (value) => value == null || value.isEmpty
                  ? context.tr('كلمة المرور مطلوبة')
                  : null,
            ),
            if (_error != null) ...[
              SizedBox(height: 12),
              Text(
                _error!,
                key: Key('login-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: 20),
            FilledButton(
              key: Key('login-submit'),
              onPressed: enabled ? _submit : null,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('تسجيل الدخول')),
              ),
            ),
            if (_busy && widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: Text(context.tr('إلغاء')),
              ),
            SizedBox(height: 16),
            Text(
              context.tr(
                'لا تتوفر استعادة كلمة المرور أو إضافة حساب ثانٍ في SIRAJ P0.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
