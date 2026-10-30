import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_v2_icons.dart';
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
          iconPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
          titleTextStyle: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 15,
            height: 2.1,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          contentTextStyle: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 11,
            height: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          icon: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 43,
              height: 43,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF44341C)
                    : const Color(0xFFFFF3DF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SirajV2Icon(
                delete ? 'trash' : 'lock',
                size: 22,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFCD80)
                    : const Color(0xFF9F640B),
              ),
            ),
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
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('إلغاء')),
            ),
            FilledButton(
              key: const Key('confirm-account-action'),
              style: delete
                  ? FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF472B34)
                          : const Color(0xFFFFF0F2),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
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

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferencesScope.maybeOf(context);
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SirajAppBar(
        title: context.tr('الإعدادات'),
        subtitle: context.copy(
          'المظهر والحساب المحلي',
          'Appearance and local account',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
              children: [
                SirajCard(
                  child: Column(
                    children: [
                      if (prefs != null) ...[
                        _SettingsRow(
                          key: const Key('v2-settings-appearance-row'),
                          title: context.copy('مظهر التطبيق', 'App appearance'),
                          caption: context.copy(
                            'الوضع الليلي والنهاري',
                            'Light and dark modes',
                          ),
                          trailing: _ChoiceStrip<ThemeMode>(
                            value: prefs.value.themeMode,
                            entries: [
                              (
                                ThemeMode.light,
                                context.copy('نهاري', 'Light'),
                                'settings-theme-light',
                              ),
                              (
                                ThemeMode.dark,
                                context.copy('ليلي', 'Dark'),
                                'settings-theme-dark',
                              ),
                              (
                                ThemeMode.system,
                                context.tr('حسب النظام'),
                                'settings-theme-system',
                              ),
                            ],
                            onChanged: (v) => unawaited(prefs.setTheme(v)),
                          ),
                        ),
                        _SettingsRow(
                          title: context.tr('اللغة'),
                          caption: context.copy(
                            'العربية أو الإنجليزية',
                            'Arabic or English',
                          ),
                          trailing: _ChoiceStrip<String>(
                            value: prefs.value.locale.languageCode,
                            entries: const [
                              ('ar', 'العربية', 'settings-language-ar'),
                              ('en', 'English', 'settings-language-en'),
                            ],
                            onChanged: (v) =>
                                unawaited(prefs.setLocale(Locale(v))),
                          ),
                        ),
                        if (prefs.persistenceFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                              context.copy(
                                'تعذر حفظ التفضيل. أعد اختيار القيمة للمحاولة.',
                                'Could not save the preference. Select the value again to retry.',
                              ),
                              style: TextStyle(color: c.error),
                            ),
                          ),
                      ],
                      _SettingsRow(
                        key: const Key('settings-resources'),
                        title: context.copy(
                          'إدارة الموارد',
                          'Manage resources',
                        ),
                        caption: context.copy(
                          'النموذج والبيانات والكتب',
                          'Model, data and books',
                        ),
                        trailing: const SirajV2Icon('chevron', size: 18),
                        onTap: onOpenResources,
                      ),
                      _SettingsRow(
                        title: context.copy('التخزين المحلي', 'Local storage'),
                        caption: context.copy(
                          'عرض الملفات المتاحة وحالتها',
                          'View available files and their status',
                        ),
                        trailing: SirajStatusPill(
                          text: context.copy('إدارة الموارد', 'Resources'),
                          tone: SirajPillTone.gray,
                        ),
                        onTap: onOpenResources,
                        divider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    context.copy('الحساب المحلي', 'Local account'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SirajCard(
                  child: Column(
                    children: [
                      _SettingsRow(
                        title: context.copy(
                          'حساب واحد على الجهاز',
                          'One account per device',
                        ),
                        caption: context.copy(
                          'بياناتك ومحادثاتك خاصة بهذا الحساب',
                          'Your data and conversations belong to this account',
                        ),
                        trailing: const SirajIconTile(
                          icon: Icons.person_outline,
                        ),
                      ),
                      _SettingsRow(
                        key: const Key('settings-logout'),
                        title: context.tr('تسجيل الخروج'),
                        caption: context.copy(
                          'العودة إلى شاشة الدخول دون حذف البيانات',
                          'Return to login without deleting data',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () =>
                              unawaited(_accountAction(context, delete: false)),
                          child: Text(context.copy('خروج', 'Log out')),
                        ),
                        onTap: () =>
                            unawaited(_accountAction(context, delete: false)),
                      ),
                      _SettingsRow(
                        key: const Key('settings-delete'),
                        title: context.tr('حذف الحساب'),
                        caption: context.copy(
                          'حذف نهائي للحساب ومحادثاته',
                          'Permanently delete this account and its conversations',
                        ),
                        trailing: OutlinedButton.icon(
                          onPressed: () =>
                              unawaited(_accountAction(context, delete: true)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF472B34)
                                : const Color(0xFFFFF0F2),
                            foregroundColor: c.error,
                            side: BorderSide(
                              color: c.error.withValues(alpha: .25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const SirajV2Icon('trash', size: 16),
                          label: Text(context.copy('حذف', 'Delete')),
                        ),
                        onTap: () =>
                            unawaited(_accountAction(context, delete: true)),
                        destructive: true,
                        divider: false,
                      ),
                    ],
                  ),
                ),
                SirajReferenceNotice(
                  text: context.copy(
                    'سراج يعمل بحساب محلي واحد. لا توجد استعادة لكلمة المرور؛ وتبقى المحادثات على الجهاز.',
                    'SIRAJ uses one local account. Password recovery is unavailable; conversations stay on this device.',
                  ),
                  icon: Icons.shield_outlined,
                ),
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
        ),
      ),
    );
  }
}

/// Presentation only: preferences and account actions remain owned by their controllers.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.title,
    required this.caption,
    required this.trailing,
    this.onTap,
    this.divider = true,
    this.destructive = false,
  });
  final String title, caption;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool divider, destructive;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: destructive ? c.error : c.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(caption, style: TextStyle(fontSize: 9, color: c.onSurfaceVariant)),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: c.outlineVariant))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 59),
          child: LayoutBuilder(
            builder: (context, box) {
              final large =
                  MediaQuery.textScalerOf(context).scale(11) > 16 ||
                  box.maxWidth < 300;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: large
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          text,
                          const SizedBox(height: 6),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: trailing,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: text),
                          const SizedBox(width: 8),
                          trailing,
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChoiceStrip<T> extends StatelessWidget {
  const _ChoiceStrip({
    required this.value,
    required this.entries,
    required this.onChanged,
  });
  final T value;
  final List<(T, String, String)> entries;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Wrap(
          children: [
            for (final e in entries)
              Semantics(
                selected: e.$1 == value,
                child: TextButton(
                  key: Key(e.$3),
                  onPressed: () => onChanged(e.$1),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    backgroundColor: e.$1 == value
                        ? c.surface
                        : Colors.transparent,
                    foregroundColor: e.$1 == value
                        ? c.primary
                        : c.onSurfaceVariant,
                    textStyle: const TextStyle(
                      fontFamily: 'NotoSansArabic',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(e.$2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
