import '../../core/design/siraj_v2_components.dart';
import '../../core/localization/siraj_copy.dart';
import 'package:flutter/material.dart';

/// Shared visual shell for B-06 account screens. Presentation only.
/// Never opens SQLite, handles session markers or chooses KDF parameters.
class AuthFormFrame extends StatelessWidget {
  const AuthFormFrame({
    super.key,
    required this.title,
    required this.description,
    required this.content,
    this.notice,
  });

  final String title;
  final String description;
  final Widget content;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: SirajAppBar(
        title: context.copy('الحساب المحلي', 'Local account'),
        subtitle: context.copy(
          'خصوصية أكبر على جهازك',
          'Privacy on your device',
        ),
        showBack: false,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(15, 37, 15, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SirajBrandMark(size: 64)),
                  SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (notice != null) ...[
                    SirajReferenceNotice(
                      text: notice!,
                      warning: true,
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 14),
                  ],
                  content,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
