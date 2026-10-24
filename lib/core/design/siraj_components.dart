import 'package:flutter/material.dart';
import 'siraj_design.dart';

class SirajCard extends StatelessWidget {
  const SirajCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SirajSpacing.x4),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class SirajButton extends StatelessWidget {
  const SirajButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => icon == null
      ? FilledButton(onPressed: onPressed, child: Text(label))
      : FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        );
}

class SirajTextField extends StatelessWidget {
  const SirajTextField({
    super.key,
    required this.label,
    this.controller,
    this.enabled = true,
  });
  final String label;
  final TextEditingController? controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    decoration: InputDecoration(labelText: label),
  );
}

class SirajStatusView extends StatelessWidget {
  const SirajStatusView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              SirajButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    ),
  );
}

class SirajLoadingView extends StatelessWidget {
  const SirajLoadingView({super.key, this.message = 'جارٍ التحميل…'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message),
      ],
    ),
  );
}

class SirajErrorView extends StatelessWidget {
  const SirajErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => SirajStatusView(
    title: 'تعذّر إكمال العملية',
    message: message,
    icon: Icons.error_outline,
    actionLabel: onRetry == null ? null : 'إعادة المحاولة',
    onAction: onRetry,
  );
}

Future<bool> showSirajConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool destructive = false,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            confirmLabel,
            style: destructive
                ? TextStyle(color: Theme.of(dialogContext).colorScheme.error)
                : null,
          ),
        ),
      ],
    ),
  );
  return answer ?? false;
}
