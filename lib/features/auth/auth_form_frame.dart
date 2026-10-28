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
      appBar: SirajAppBar(title: context.tr('سراج'), showBack: false),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(15, 38, 15, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SirajBrandMark(size: 64)),
                  SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(height: 24),
                  content,
                  if (notice != null) ...[
                    SizedBox(height: 16),
                    Text(
                      notice!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
