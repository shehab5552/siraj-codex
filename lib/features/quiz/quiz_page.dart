import '../../app/presentation/siraj_problem.dart';
import '../../integrations/ai/quiz_port.dart';
import '../../core/localization/siraj_copy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../integrations/ai/tutor_contract.dart';
import 'quiz_controller.dart';
import 'quiz_widgets.dart';
import 'quiz_curriculum.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.controller,
    this.curriculum = const UnavailableQuizCurriculum(),
  });
  final QuizCurriculumPort curriculum;
  final QuizController controller;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  QuizController get c => widget.controller;
  late final QuizSetupController _setup = QuizSetupController(
    catalog: widget.curriculum,
    availability: () => c.availability,
  );
  @override
  void initState() {
    super.initState();
    unawaited(c.initialize());
    unawaited(_setup.load());
  }

  @override
  void dispose() {
    _setup.dispose();
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

  Widget _questionContent(QuizQuestionView question, int index) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.copy(
          'السؤال ${index + 1} من ${c.questionCount}',
          'Question ${index + 1} of ${c.questionCount}',
        ),
      ),
      const SizedBox(height: 16),
      QuizQuestionForm(
        key: ValueKey(question.id),
        question: question,
        feedback: null,
        initialAnswer: c.draftAnswer,
        onDraftChanged: (answer) => c.setDraftAnswerFor(question.id, answer),
        busy: c.busy,
        onAnswer: (answer) => c.setDraftAnswerFor(question.id, answer),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < question.sources.length; i++)
            ActionChip(
              key: Key('quiz-source-$i'),
              label: Text(context.copy('المصدر ${i + 1}', 'Source ${i + 1}')),
              onPressed: () {
                if (c.question?.id == question.id) {
                  unawaited(_source(question.sources[i]));
                }
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (index > 0)
            OutlinedButton(
              key: const Key('quiz-previous'),
              onPressed: () {
                if (c.question?.id == question.id) {
                  unawaited(c.goToQuestion(index - 1));
                }
              },
              child: Text(context.tr('السابق')),
            ),
          FilledButton(
            key: const Key('quiz-next'),
            onPressed: () {
              if (c.question?.id == question.id) {
                unawaited(
                  index + 1 < c.questionCount
                      ? c.goToQuestion(index + 1)
                      : c.enterReview(),
                );
              }
            },
            child: Text(
              index + 1 < c.questionCount
                  ? context.tr('السؤال التالي')
                  : context.copy('مراجعة الإجابات', 'Review answers'),
            ),
          ),
        ],
      ),
    ],
  );
  Future<void> _confirmSubmit() async {
    final expected = c.sessionIdentity;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.copy('تأكيد التسليم', 'Confirm submission')),
        content: Text(
          context.copy(
            'ستُقيّم الإجابات وفق المعيار المراجَع. لن تُحفظ المحاولة خارج هذه الجلسة.',
            'Answers will be graded against the reviewed criteria. This attempt will not be saved outside this session.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('إلغاء')),
          ),
          FilledButton(
            key: const Key('quiz-final-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('تأكيد')),
          ),
        ],
      ),
    );
    if (mounted &&
        confirmed == true &&
        c.phase == QuizPhase.review &&
        identical(expected, c.sessionIdentity)) {
      await c.finishReview();
    }
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
                        context.copy(
                          SirajProblem.from(QuizFailure(error)).arabic,
                          SirajProblem.from(QuizFailure(error)).english,
                        ),
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
                  QuizSetupForm(
                    setup: _setup,
                    busy: c.busy,
                    onStart: (selection) =>
                        unawaited(c.startSelection(selection)),
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
                  _questionContent(c.question!, c.index),
                ],
                if (c.phase == QuizPhase.review) ...[
                  Text(
                    context.copy('مراجعة الاختبار', 'Review quiz'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    context.copy(
                      '${c.answeredCount} من ${c.questionCount} إجابات صالحة للتسليم',
                      '${c.answeredCount} of ${c.questionCount} answers are valid for submission',
                    ),
                  ),
                  for (var i = 0; i < c.reviewQuestions.length; i++)
                    Card(
                      child: ListTile(
                        title: Text(c.reviewQuestions[i].stem),
                        subtitle: Text(
                          c.answerAt(i) == null
                              ? context.copy('لم تُجب بعد', 'Not answered')
                              : context.copy(
                                  'إجابة محفوظة في الجلسة',
                                  'Answer saved in this session',
                                ),
                        ),
                        trailing: TextButton(
                          key: Key('quiz-edit-$i'),
                          onPressed: () => unawaited(c.goToQuestion(i)),
                          child: Text(context.copy('تعديل', 'Edit')),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('quiz-confirm-submit'),
                    onPressed: c.busy
                        ? null
                        : () => unawaited(_confirmSubmit()),
                    child: Text(
                      context.copy('تسليم الإجابات', 'Submit answers'),
                    ),
                  ),
                ],
                if (c.summary case final summary?)
                  QuizSummaryView(summary: summary),
                if (c.phase == QuizPhase.question ||
                    c.phase == QuizPhase.review ||
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
