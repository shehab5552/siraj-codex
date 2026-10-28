import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../core/design/siraj_components.dart';
import '../../core/design/siraj_design.dart';
import '../../core/design/siraj_v2_components.dart';
import '../../core/localization/siraj_copy.dart';

/// Actual callbacks/history are supplied by the guarded composition root.
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
      appBar: SirajAppBar(
        title: context.tr('سراج'),
        subtitle: context.copy(
          'مساعدك الدراسي — تعلم محلي موثوق',
          'Your study companion — trusted local learning',
        ),
        showBack: false,
        actions: [
          if (onOpenHistory != null)
            IconButton(
              key: const Key('open-chat-history'),
              tooltip: context.tr('محادثاتي المحفوظة'),
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history, size: 20),
            ),
          if (onOpenSettings != null)
            IconButton(
              key: const Key('open-settings'),
              tooltip: context.tr('الإعدادات'),
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
              children: [
                Container(
                  key: const Key('v2-home-hero'),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [SirajPalette.navy, Color(0xFF1D537B)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -32,
                        top: -64,
                        child: ExcludeSemantics(
                          child: Container(
                            width: 165,
                            height: 165,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .13),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: .04),
                                  spreadRadius: 28,
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: .02),
                                  spreadRadius: 56,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.copy(
                                'مرحبًا بك في عالم التعلّم',
                                'Welcome to a world of learning',
                              ),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFDAE8F6),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.copy(
                                'كل سؤال يقربك\nمن الفهم',
                                'Every question brings\nyou closer to understanding',
                              ),
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 7),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 270),
                              child: Text(
                                authenticated
                                    ? context.copy(
                                        'سراج يساعدك على المذاكرة، ويعرض مصادر التفسير حين تتوفر الموارد المعتمدة.',
                                        'SIRAJ helps you study and shows supporting sources when approved resources are available.',
                                      )
                                    : context.copy(
                                        'معاينة تصميمية فقط. لا توجد جلسة أو إجابات تجريبية.',
                                        'Design preview only. No authenticated session or demo answers.',
                                      ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.9,
                                  color: Color(0xFFDAE8F6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              key: const Key('open-chat'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF123C62),
                              ),
                              onPressed:
                                  onOpenChat ??
                                  () => Navigator.of(
                                    context,
                                  ).pushNamed(AppRoutes.chat),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                              ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SirajCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.copy('حالة المساعد', 'Assistant status'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Flexible(
                            child: SirajStatusPill(
                              text: context.copy(
                                'لم تثبت الجاهزية',
                                'Readiness not established',
                              ),
                              warning: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.copy(
                          'لم تثبت جاهزية LLM وRAG بعد. راجع الملفات والتوافق قبل التوليد.',
                          'LLM and RAG readiness is not yet established. Check files and compatibility before generation.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (authenticated && onOpenResources != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            key: const Key('open-resource-status'),
                            onPressed: onOpenResources,
                            icon: const Icon(Icons.tune, size: 16),
                            label: Text(context.tr('حالة الموارد')),
                          ),
                        ),
                    ],
                  ),
                ),
                if (authenticated) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 15, bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.copy('إلى أين نذهب؟', 'Where shall we go?'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            context.copy(
                              'اختر ما تريد',
                              'Choose your next step',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(14) > 21
                          ? 1
                          : constraints.maxWidth >= 700
                          ? 4
                          : 2;
                      final entries =
                          <
                            (
                              IconData,
                              String,
                              String,
                              String,
                              VoidCallback?,
                              bool,
                              Key?,
                            )
                          >[
                            (
                              Icons.chat_bubble_outline,
                              'المساعد',
                              'اسأل، افهم، وتابع الشرح',
                              'Ask, understand and follow up',
                              onOpenChat,
                              false,
                              null,
                            ),
                            (
                              Icons.menu_book_outlined,
                              'المكتبة',
                              'مواد وكتب PDF محلية',
                              'Local books and PDF resources',
                              onOpenLibrary,
                              true,
                              null,
                            ),
                            (
                              Icons.school_outlined,
                              'الاختبارات',
                              'راجع فهمك بالدروس',
                              'Review your understanding',
                              onOpenQuiz,
                              false,
                              const Key('open-quiz'),
                            ),
                            (
                              Icons.download_outlined,
                              'تجهيز الموارد',
                              'تنزيل وتحقق وجاهزية',
                              'Downloads, checks and readiness',
                              onOpenResources,
                              true,
                              null,
                            ),
                          ];
                      return Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          for (final e in entries)
                            if (e.$5 != null)
                              SizedBox(
                                width:
                                    (constraints.maxWidth - 9 * (columns - 1)) /
                                    columns,
                                child: Card(
                                  child: InkWell(
                                    key: e.$7,
                                    onTap: e.$5,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(13),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SirajIconTile(
                                            icon: e.$1,
                                            teal: e.$6,
                                            size: 38,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            context.tr(e.$2),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            context.copy(e.$3, e.$4),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(fontSize: 9),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 15, bottom: 10),
                    child: Text(
                      context.tr('أحدث محادثة محفوظة'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (latestConversationTitle != null && onOpenLatest != null)
                    SirajCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const SirajIconTile(icon: Icons.history),
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
                    SirajCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        context.tr('لا توجد محادثات محفوظة بعد.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
