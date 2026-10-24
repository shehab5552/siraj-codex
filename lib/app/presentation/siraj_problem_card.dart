import 'package:flutter/material.dart';
import '../../core/localization/siraj_copy.dart';
import 'siraj_problem.dart';

class SirajProblemCard extends StatelessWidget {
  const SirajProblemCard({
    super.key,
    required this.problem,
    this.onRetry,
    this.onRedownload,
    this.onResources,
    this.onLogin,
  });
  final SirajProblem problem;
  final VoidCallback? onRetry, onRedownload, onResources, onLogin;
  @override
  Widget build(BuildContext context) {
    final action = switch (problem.action) {
      ProblemAction.retry => onRetry,
      ProblemAction.redownload => onRedownload,
      ProblemAction.resources => onResources,
      ProblemAction.login => onLogin,
      ProblemAction.back => null,
    };
    final label = switch (problem.action) {
      ProblemAction.retry => context.tr('إعادة المحاولة'),
      ProblemAction.redownload => context.copy(
        'إعادة التنزيل',
        'Download again',
      ),
      ProblemAction.resources => context.tr('حالة الموارد'),
      ProblemAction.login => context.tr('تسجيل الدخول'),
      ProblemAction.back => context.tr('السابق'),
    };
    return Semantics(
      liveRegion: true,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(context.copy(problem.arabic, problem.english)),
                  ),
                ],
              ),
              if (action != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(onPressed: action, child: Text(label)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
