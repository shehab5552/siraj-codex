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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('المصدر غير متاح حاليًا.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: c,
        builder: (context, _) => AlertDialog(
          title: const Text('مصدر السؤال'),
          content: SingleChildScrollView(
            child: c.question?.id != questionId || c.phase != QuizPhase.question
                ? const Text('انتهت جلسة الاختبار؛ لن يعرض المصدر.')
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
                      if (source.page != null) Text('صفحة ${source.page}'),
                      const SizedBox(height: 12),
                      Text(source.snippet),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AnimatedBuilder(
      animation: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('اختبر فهمك')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (c.phase == QuizPhase.loading)
                const Center(child: CircularProgressIndicator())
              else if (c.phase == QuizPhase.sessionExpired)
                const Text('انتهت صلاحية الجلسة. يلزم تسجيل الدخول.')
              else ...[
                if (c.error case final error?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        quizErrorText(error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (c.needsCleanupRetry)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      key: const Key('quiz-retry-cleanup'),
                      onPressed: () => unawaited(c.retryCleanup()),
                      child: const Text('إعادة محاولة الإنهاء'),
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
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Text('جارٍ إعداد أسئلة الاختبار والتحقق منها…'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    key: const Key('quiz-cancel'),
                    onPressed: () => unawaited(c.end()),
                    child: const Text('إلغاء الطلب'),
                  ),
                ],
                if (c.phase == QuizPhase.question && c.question != null) ...[
                  Text('السؤال ${c.index + 1} من ${c.questionCount}'),
                  const SizedBox(height: 16),
                  QuizQuestionForm(
                    key: ValueKey(c.question!.id),
                    question: c.question!,
                    feedback: c.feedback,
                    busy: c.busy,
                    onAnswer: (answer) => unawaited(c.submit(answer)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < c.question!.sources.length; i++)
                        ActionChip(
                          key: Key('quiz-source-$i'),
                          label: Text('المصدر ${i + 1}'),
                          onPressed: () =>
                              unawaited(_source(c.question!.sources[i])),
                        ),
                    ],
                  ),
                  if (c.feedback != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('quiz-next'),
                      onPressed: c.next,
                      child: Text(
                        c.index + 1 < c.questionCount
                            ? 'السؤال التالي'
                            : 'عرض النتيجة',
                      ),
                    ),
                  ],
                ],
                if (c.summary case final summary?)
                  QuizSummaryView(summary: summary),
                if (c.phase == QuizPhase.question ||
                    c.phase == QuizPhase.summary) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    key: const Key('quiz-end'),
                    onPressed: () => unawaited(c.end()),
                    child: const Text('إنهاء الاختبار'),
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
