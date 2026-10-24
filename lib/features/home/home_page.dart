import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../core/design/siraj_components.dart';
import '../../core/design/siraj_design.dart';
import '../../core/localization/siraj_copy.dart';

/// Presentation only. The composition root supplies guarded navigation and
/// actual history; no conversation or resource status is fabricated here.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.onOpenChat,
    this.onOpenResources,
    this.onOpenHistory,
    this.onOpenQuiz,
    this.onOpenLibrary,
    this.onOpenSettings,
    this.latestConversationTitle,
    this.onOpenLatest,
  });
  final VoidCallback? onOpenChat,
      onOpenResources,
      onOpenHistory,
      onOpenQuiz,
      onOpenLibrary,
      onOpenSettings,
      onOpenLatest;
  final String? latestConversationTitle;
  @override
  Widget build(BuildContext context) {
    final authenticated = onOpenChat != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('سراج')),
        actions: [
          if (onOpenHistory != null)
            IconButton(
              key: const Key('open-chat-history'),
              tooltip: context.tr('محادثاتي المحفوظة'),
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history),
            ),
          if (onOpenSettings != null)
            IconButton(
              key: const Key('open-settings'),
              tooltip: context.tr('الإعدادات'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.tr('مرحبًا بك في سراج'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: SirajPalette.navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('تعلّم بثقة، حتى دون اتصال بالإنترنت'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authenticated
                            ? context.copy(
                                'مساحتك المحلية للمحادثات والمراجعة والمصادر المعتمدة.',
                                'Your local space for conversations, revision and approved sources.',
                              )
                            : context.copy(
                                'معاينة تصميمية فقط. لا توجد جلسة أو إجابات تجريبية.',
                                'Design preview only. No authenticated session or demo answers.',
                              ),
                        style: const TextStyle(color: Color(0xFFDFE9F7)),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('open-chat'),
                        onPressed:
                            onOpenChat ??
                            () =>
                                Navigator.of(context).pushNamed(AppRoutes.chat),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(
                          context.tr(
                            authenticated
                                ? 'فتح المحادثة'
                                : 'فتح معاينة المحادثة',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SirajCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr('جاهزية الموارد'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.copy(
                          'لم تثبت جاهزية LLM وRAG بعد. راجع الملفات والتوافق قبل التوليد.',
                          'LLM and RAG readiness is not yet established. Check files and compatibility before generation.',
                        ),
                      ),
                      if (authenticated && onOpenResources != null)
                        OutlinedButton.icon(
                          key: const Key('open-resource-status'),
                          onPressed: onOpenResources,
                          icon: const Icon(Icons.tune),
                          label: Text(context.tr('حالة الموارد')),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (authenticated) ...[
                  Text(
                    context.tr('الوصول السريع'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 700;
                      final columns =
                          MediaQuery.textScalerOf(context).scale(14) > 21
                          ? 1
                          : wide
                          ? 4
                          : 2;
                      final entries = <(IconData, String, VoidCallback?)>[
                        (Icons.chat_bubble_outline, 'المساعد', onOpenChat),
                        (Icons.menu_book_outlined, 'المكتبة', onOpenLibrary),
                        (Icons.quiz_outlined, 'الاختبارات', onOpenQuiz),
                        (
                          Icons.download_outlined,
                          'تجهيز الموارد',
                          onOpenResources,
                        ),
                      ];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in entries)
                            if (entry.$3 != null)
                              SizedBox(
                                width:
                                    (constraints.maxWidth - 8 * (columns - 1)) /
                                    columns,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: entry.$3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Icon(
                                            entry.$1,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            context.tr(entry.$2),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                  if (onOpenQuiz != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        key: const Key('open-quiz'),
                        onPressed: onOpenQuiz,
                        child: Text(context.tr('اختبر فهمك')),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('أحدث محادثة محفوظة'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (latestConversationTitle != null && onOpenLatest != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          latestConversationTitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: onOpenLatest,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    )
                  else
                    Text(context.tr('لا توجد محادثات محفوظة بعد.')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
