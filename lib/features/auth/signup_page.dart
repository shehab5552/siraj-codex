import '../../core/localization/siraj_copy.dart';
import '../../core/design/siraj_v2_components.dart';
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
          _error = context.tr(
            'تعذّر إنشاء الحساب. تحقق من البيانات وحاول مجددًا.',
          );
        });
      }
    } catch (_) {
      // Do not surface platform details, hashes, account IDs or passwords.
      if (mounted) {
        setState(
          () => _error = context.tr(
            'تعذّر إنشاء الحساب. تحقق من البيانات وحاول مجددًا.',
          ),
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
        notice: context.tr(
          'حُفظ الحساب، وتعذّر إكمال الجلسة. سجّل الدخول للمتابعة.',
        ),
      );
    }
    final enabled = widget.onCreateAccount != null && !_busy;
    return AuthFormFrame(
      title: context.copy(
        'ابدأ رحلتك مع سراج',
        'Start your journey with SIRAJ',
      ),
      description: context.copy(
        'حساب واحد، خصوصية أكبر، وتعليم يعمل محليًا',
        'One account, more privacy and local learning',
      ),
      notice: widget.onCreateAccount == null
          ? context.tr(
              'واجهة إنشاء الحساب جاهزة، لكنها غير مفعّلة حتى اعتماد حماية كلمة المرور الإنتاجية.',
            )
          : context.tr(
              'يُحفظ الحساب محليًا. لا تتوفر استعادة كلمة مرور منسية في P0.',
            ),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SirajLabeledField(
              label: context.tr('اسم المستخدم'),
              child: TextFormField(
                key: Key('signup-username'),
                style: const TextStyle(fontSize: 12, letterSpacing: 0),
                controller: _username,
                enabled: enabled,
                textInputAction: TextInputAction.next,
                autofillHints: [AutofillHints.newUsername],
                decoration: InputDecoration(
                  hintText: context.copy(
                    'مثال: اسم المستخدم',
                    'Example: username',
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr('اسم المستخدم مطلوب')
                    : null,
              ),
            ),
            SizedBox(height: 14),
            TextFormField(
              key: Key('signup-password'),
              controller: _password,
              enabled: enabled,
              obscureText: _hidePassword,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('كلمة المرور'),
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
            SizedBox(height: 14),
            SirajLabeledField(
              label: context.tr('تأكيد كلمة المرور'),
              child: TextFormField(
                key: Key('signup-confirmation'),
                style: const TextStyle(fontSize: 12, letterSpacing: 0),
                controller: _confirmation,
                enabled: enabled,
                obscureText: _hideConfirmation,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _hideConfirmation
                        ? context.tr('إظهار التأكيد')
                        : context.tr('إخفاء التأكيد'),
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
                    return context.tr('تأكيد كلمة المرور مطلوب');
                  }

                  if (value != _password.text) {
                    return context.tr('كلمتا المرور غير متطابقتين');
                  }

                  return null;
                },
              ),
            ),
            SizedBox(height: 12),
            Text(
              context.tr(
                'احتفظ بكلمة المرور في مكان آمن؛ لا توجد آلية لاستعادتها في هذه النسخة.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              SizedBox(height: 12),
              Text(
                _error!,
                key: Key('signup-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: 20),
            FilledButton(
              key: Key('signup-submit'),
              onPressed: enabled ? _submit : null,
              child: _busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('إنشاء الحساب')),
            ),
            if (_busy && widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: Text(context.tr('إلغاء')),
              ),
          ],
        ),
      ),
    );
  }
}
