import '../../core/localization/siraj_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../integrations/ai/tutor_contract.dart';
import 'quiz_controller.dart';
import 'quiz_widgets.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.controller});
  final QuizController controller;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  QuizController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    unawaited(c.initialize());
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _source(SourceReference ref) async {
    final questionId = c.question?.id;
    final source = await c.openSource(ref);
    if (!mounted ||
        c.phase != QuizPhase.question ||
        c.question?.id != questionId) {
      return;
    }
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('المصدر غير متاح حاليًا.'))),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: c,
        builder: (context, _) => AlertDialog(
          title: Text(context.tr('مصدر السؤال')),
          content: SingleChildScrollView(
            child: c.question?.id != questionId || c.phase != QuizPhase.question
                ? Text(context.tr('انتهت جلسة الاختبار؛ لن يعرض المصدر.'))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final text in [
                        source.subject,
                        source.unit,
                        source.lesson,
                        source.document,
                      ])
                        if (text != null && text.trim().isNotEmpty) Text(text),
                      if (source.page != null)
                        Text(
                          context.copy(
                            'صفحة ${source.page}',
                            'Page ${source.page}',
                          ),
                        ),
                      SizedBox(height: 12),
                      Text(source.snippet),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('إغلاق')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: SirajCopy.isArabic(context)
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: AnimatedBuilder(
      animation: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('اختبر فهمك'))),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(20),
            children: [
              if (c.phase == QuizPhase.loading)
                Center(child: CircularProgressIndicator())
              else if (c.phase == QuizPhase.sessionExpired)
                Text(context.tr('انتهت صلاحية الجلسة. يلزم تسجيل الدخول.'))
              else ...[
                if (c.error case final error?)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        context.tr(quizErrorText(error)),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (c.needsCleanupRetry)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      key: Key('quiz-retry-cleanup'),
                      onPressed: () => unawaited(c.retryCleanup()),
                      child: Text(context.tr('إعادة محاولة الإنهاء')),
                    ),
                  ),
                if (c.phase == QuizPhase.idle)
                  QuizRequestForm(
                    busy: c.busy,
                    onStart: (text, {desiredCount, desiredType}) => unawaited(
                      c.start(
                        text,
                        desiredCount: desiredCount,
                        desiredType: desiredType,
                      ),
                    ),
                  ),
                if (c.phase == QuizPhase.generating) ...[
                  Center(child: CircularProgressIndicator()),
                  SizedBox(height: 16),
                  Text(context.tr('جارٍ إعداد أسئلة الاختبار والتحقق منها…')),
                  SizedBox(height: 16),
                  OutlinedButton(
                    key: Key('quiz-cancel'),
                    onPressed: () => unawaited(c.end()),
                    child: Text(context.tr('إلغاء الطلب')),
                  ),
                ],
                if (c.phase == QuizPhase.question && c.question != null) ...[
                  Text(
                    context.copy(
                      'السؤال ${c.index + 1} من ${c.questionCount}',
                      'Question ${c.index + 1} of ${c.questionCount}',
                    ),
                  ),
                  SizedBox(height: 16),
                  QuizQuestionForm(
                    key: ValueKey(c.question!.id),
                    question: c.question!,
                    feedback: c.feedback,
                    busy: c.busy,
                    onAnswer: (answer) => unawaited(c.submit(answer)),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < c.question!.sources.length; i++)
                        ActionChip(
                          key: Key('quiz-source-$i'),
                          label: Text(
                            context.copy('المصدر ${i + 1}', 'Source ${i + 1}'),
                          ),
                          onPressed: () =>
                              unawaited(_source(c.question!.sources[i])),
                        ),
                    ],
                  ),
                  if (c.feedback != null) ...[
                    SizedBox(height: 16),
                    FilledButton(
                      key: Key('quiz-next'),
                      onPressed: c.next,
                      child: Text(
                        c.index + 1 < c.questionCount
                            ? context.tr('السؤال التالي')
                            : context.tr('عرض النتيجة'),
                      ),
                    ),
                  ],
                ],
                if (c.summary case final summary?)
                  QuizSummaryView(summary: summary),
                if (c.phase == QuizPhase.question ||
                    c.phase == QuizPhase.summary) ...[
                  SizedBox(height: 16),
                  OutlinedButton(
                    key: Key('quiz-end'),
                    onPressed: () => unawaited(c.end()),
                    child: Text(context.tr('إنهاء الاختبار')),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
