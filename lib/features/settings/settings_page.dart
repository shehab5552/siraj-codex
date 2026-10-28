import '../../core/design/siraj_v2_components.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/app_preferences.dart';
import '../../app/app_session_controller.dart';
import '../../core/design/siraj_components.dart';
import '../../core/localization/siraj_copy.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.onOpenResources,
  });
  final AppSessionController session;
  final VoidCallback onOpenResources;
  Future<void> _accountAction(
    BuildContext context, {
    required bool delete,
  }) async {
    var checked = false;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: Icon(
            delete ? Icons.delete_outline : Icons.logout,
            color: delete ? Theme.of(context).colorScheme.error : null,
          ),
          title: Text(context.tr(delete ? 'حذف الحساب' : 'تسجيل الخروج')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  delete
                      ? context.copy(
                          'سيتم حذف هذا الحساب ومحادثاته نهائيًا، ولا يمكن استعادة بياناته',
                          'This account and its conversations will be permanently deleted. Its data cannot be recovered.',
                        )
                      : context.copy(
                          'ستبقى بيانات حسابك ومحادثاتك والموارد على الجهاز. يلزم إدخال كلمة المرور للدخول مجددًا.',
                          'Your account, conversations and resources will remain on this device. Your password is required to log in again.',
                        ),
                ),
                if (delete)
                  CheckboxListTile(
                    key: const Key('delete-account-checkbox'),
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    onChanged: (value) =>
                        setState(() => checked = value == true),
                    title: Text(
                      context.copy(
                        'أفهم أن الحذف نهائي',
                        'I understand deletion is permanent',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('إلغاء')),
            ),
            FilledButton(
              key: const Key('confirm-account-action'),
              onPressed: delete && !checked
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(context.tr(delete ? 'حذف الحساب' : 'تسجيل الخروج')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      if (delete) {
        await session.deleteAccount(confirmed: true);
      } else {
        await session.logout();
      }
    } catch (_) {
      /* The root displays a safe revocation failure after route removal. */
    }
  }

  Widget _selector<T>({
    required Key key,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        key: key,
        value: value,
        isExpanded: true,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferencesScope.maybeOf(context);
    return Scaffold(
      appBar: SirajAppBar(
        title: context.tr('الإعدادات'),
        subtitle: context.copy(
          'الحساب والمظهر وإدارة الموارد',
          'Account, appearance and resources',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (prefs != null) ...[
                  Text(
                    context.tr('المظهر'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SirajCard(
                    child: Column(
                      children: [
                        _selector<ThemeMode>(
                          key: const Key('settings-theme'),
                          value: prefs.value.themeMode,
                          label: context.tr('المظهر'),
                          items: [
                            for (final mode in ThemeMode.values)
                              DropdownMenuItem(
                                value: mode,
                                child: Text(
                                  context.tr(switch (mode) {
                                    ThemeMode.system => 'حسب النظام',
                                    ThemeMode.light => 'فاتح',
                                    ThemeMode.dark => 'داكن',
                                  }),
                                ),
                              ),
                          ],
                          onChanged: (mode) {
                            if (mode != null) unawaited(prefs.setTheme(mode));
                          },
                        ),
                        const SizedBox(height: 16),
                        _selector<String>(
                          key: const Key('settings-language'),
                          value: prefs.value.locale.languageCode,
                          label: context.tr('اللغة'),
                          items: [
                            DropdownMenuItem(
                              value: 'ar',
                              child: Text(context.tr('العربية')),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(context.tr('الإنجليزية')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              unawaited(prefs.setLocale(Locale(value)));
                            }
                          },
                        ),
                        if (prefs.persistenceFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              context.copy(
                                'تعذر حفظ التفضيل. أعد اختيار القيمة للمحاولة.',
                                'Could not save the preference. Select the value again to retry.',
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SirajCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(context.tr('حالة الموارد')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: onOpenResources,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('الحساب'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SirajCard(
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('settings-logout'),
                        leading: const Icon(Icons.logout),
                        title: Text(context.tr('تسجيل الخروج')),
                        onTap: () =>
                            unawaited(_accountAction(context, delete: false)),
                      ),
                      const Divider(),
                      ListTile(
                        key: const Key('settings-delete'),
                        leading: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          context.tr('حذف الحساب'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        onTap: () =>
                            unawaited(_accountAction(context, delete: true)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SirajCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('معلومات التطبيق'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.copy(
                          'سراج P0 • حساب محلي واحد • المحادثات على الجهاز. الاختبارات في ذاكرة الجلسة فقط. تشغيل الذكاء الاصطناعي مرتبط بموارد معتمدة ومتوافقة.',
                          'SIRAJ P0 • One local account • Conversations on this device. Quizzes live in session memory only. AI requires approved, compatible resources.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'SIRAJ',
                        ),
                        child: Text(
                          context.copy(
                            'تراخيص المصادر المفتوحة',
                            'Open source licenses',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
