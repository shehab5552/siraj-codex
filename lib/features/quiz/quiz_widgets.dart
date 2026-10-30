import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_v2_icons.dart';
import '../../core/design/siraj_components.dart';
export 'quiz_copy.dart' show quizErrorText;
import '../../core/localization/siraj_copy.dart';
import 'package:flutter/material.dart';
import '../../integrations/ai/quiz_port.dart';
import 'quiz_controller.dart';
import 'quiz_curriculum.dart';

class QuizSetupForm extends StatelessWidget {
  const QuizSetupForm({
    super.key,
    required this.setup,
    required this.busy,
    required this.onStart,
  });
  final QuizSetupController setup;
  final bool busy;
  final ValueChanged<QuizSelection> onStart;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: setup,
    builder: (context, _) {
      final data = setup.snapshot;
      final subjects = data?.subjects ?? const <QuizSubject>[];
      final selected = subjects.where((s) => s.id == setup.subjectId);
      final units = selected.isEmpty
          ? const <QuizUnit>[]
          : selected.first.units;
      String label(String ar, String en) => context.copy(ar, en);
      Widget field<T>(
        String name,
        Key key,
        T? value,
        List<DropdownMenuItem<T>> items,
        ValueChanged<T?>? changed,
      ) => InputDecorator(
        decoration: InputDecoration(labelText: name),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            key: key,
            value: value,
            isExpanded: true,
            hint: Text(context.copy('اختر', 'Choose')),
            items: items,
            onChanged: changed,
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SirajSectionHeading(
            title: context.copy('اختبر معلوماتك', 'Test your knowledge'),
            description: context.copy(
              'اختر مادة واحدة ووحدة منها، ثم نوع الأسئلة وعددها.',
              'Choose one subject and unit, then the question type and count.',
            ),
            icon: Icons.school_outlined,
            teal: true,
          ),
          if (setup.loading) const LinearProgressIndicator(),
          if (data == null && !setup.loading)
            Card(
              key: const Key('quiz-catalog-unavailable'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.copy(
                        'فهرس المواد والوحدات المعتمد غير متاح. لا يمكن إنشاء اختبار أو اختراع أسماء مواد وحدود للأسئلة.',
                        'The approved subject and unit catalog is unavailable. A quiz cannot be created and subject names or question limits cannot be invented.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setup.load(),
                      child: Text(context.tr('إعادة المحاولة')),
                    ),
                  ],
                ),
              ),
            ),
          if (data != null) ...[
            SirajCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.copy('١. اختر المادة', '1. Choose subject'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  field<String>(
                    context.copy('المادة', 'Subject'),
                    const Key('quiz-subject'),
                    setup.subjectId,
                    [
                      for (final subject in subjects)
                        DropdownMenuItem(
                          value: subject.id,
                          child: Text(
                            label(subject.arabicName, subject.englishName),
                          ),
                        ),
                    ],
                    busy ? null : setup.selectSubject,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.copy('٢. اختر الوحدة', '2. Choose unit'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  field<String>(
                    context.tr('الوحدة'),
                    const Key('quiz-unit-selector'),
                    setup.unitId,
                    [
                      for (final unit in units)
                        DropdownMenuItem(
                          value: unit.id,
                          child: Text(label(unit.arabicName, unit.englishName)),
                        ),
                    ],
                    busy || units.isEmpty ? null : setup.selectUnit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            SirajCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.copy(
                      '٣. حدد نوع الاختبار',
                      '3. Choose question type',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) => Wrap(
                      key: const Key('quiz-request-type'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in QuizQuestionType.values)
                          SizedBox(
                            width:
                                MediaQuery.textScalerOf(context).scale(14) > 21
                                ? box.maxWidth
                                : (box.maxWidth - 8) / 2,
                            child: Semantics(
                              selected: setup.type == type,
                              button: true,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 62),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 11,
                                  ),
                                  backgroundColor: setup.type == type
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surface,
                                  side: BorderSide(
                                    color: setup.type == type
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                    width: setup.type == type ? 1.5 : 1,
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () => setup.selectType(type),
                                child: Padding(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      SirajReferenceIcon(switch (type) {
                                        QuizQuestionType.mcq =>
                                          Icons.school_outlined,
                                        QuizQuestionType.trueFalse =>
                                          Icons.check,
                                        QuizQuestionType.numeric =>
                                          Icons.calculate_outlined,
                                        QuizQuestionType.shortAnswer =>
                                          Icons.description_outlined,
                                      }, size: 21),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr(switch (type) {
                                          QuizQuestionType.mcq =>
                                            'اختيار من متعدد',
                                          QuizQuestionType.trueFalse =>
                                            'صح أو خطأ',
                                          QuizQuestionType.numeric =>
                                            'مسألة عددية',
                                          QuizQuestionType.shortAnswer =>
                                            'إجابة قصيرة',
                                        }),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.copy('عدد الأسئلة', 'Question count'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    key: const Key('quiz-count'),
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final n in data.allowedCounts[setup.type] ?? <int>[])
                        ChoiceChip(
                          label: Text('$n'),
                          selected: setup.count == n,
                          onSelected: busy ? null : (_) => setup.selectCount(n),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!setup.resourcesReady)
            Text(
              context.copy(
                'النموذج المحلي أو RAG المتوافق غير جاهز. لن تُولّد أسئلة تجريبية.',
                'The local model or compatible RAG is not ready. No demo questions will be generated.',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('quiz-start'),
            onPressed: busy || !setup.canStart
                ? null
                : () => onStart(setup.selection!),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(context.tr('إنشاء الاختبار')),
          ),
        ],
      );
    },
  );
}

class QuizQuestionForm extends StatefulWidget {
  const QuizQuestionForm({
    super.key,
    required this.question,
    required this.feedback,
    required this.onAnswer,
    required this.busy,
    this.initialAnswer,
    this.onDraftChanged,
  });
  final QuizAnswer? initialAnswer;
  final ValueChanged<QuizAnswer?>? onDraftChanged;
  final QuizQuestionView question;
  final QuizFeedback? feedback;
  final ValueChanged<QuizAnswer> onAnswer;
  final bool busy;
  @override
  State<QuizQuestionForm> createState() => _QuizQuestionFormState();
}

class _QuizQuestionFormState extends State<QuizQuestionForm> {
  String? _choice;
  bool? _boolean;
  final _value = TextEditingController(),
      _unit = TextEditingController(),
      _short = TextEditingController();
  @override
  void initState() {
    super.initState();
    switch (widget.initialAnswer) {
      case ChoiceAnswer a:
        _choice = a.optionId;
      case BooleanAnswer a:
        _boolean = a.value;
      case NumericAnswer a:
        _value.text = a.value;
        _unit.text = a.unit;
      case ShortAnswer a:
        _short.text = a.text;
      case null:
        break;
    }
    for (final input in [_value, _unit, _short]) {
      input.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
    widget.onDraftChanged?.call(_answer);
  }

  @override
  void dispose() {
    _value.dispose();
    _unit.dispose();
    _short.dispose();
    super.dispose();
  }

  bool get _enabled => widget.feedback == null && !widget.busy;
  QuizAnswer? get _answer => switch (widget.question.type) {
    QuizQuestionType.mcq => _choice == null ? null : ChoiceAnswer(_choice!),
    QuizQuestionType.trueFalse =>
      _boolean == null ? null : BooleanAnswer(_boolean!),
    QuizQuestionType.numeric => NumericAnswer(_value.text, unit: _unit.text),
    QuizQuestionType.shortAnswer => ShortAnswer(_short.text),
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SirajCard(
        child: Text(
          widget.question.stem,
          style: const TextStyle(
            fontSize: 13,
            height: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      SizedBox(height: 16),
      switch (widget.question.type) {
        QuizQuestionType.mcq => Column(
          children: [
            for (var i = 0; i < widget.question.options.length; i++)
              _QuizChoice(
                key: Key('quiz-option-${widget.question.options[i].id}'),
                selected: _choice == widget.question.options[i].id,
                label: widget.question.options[i].text,
                marker: context.copy(
                  i < 4 ? ['أ', 'ب', 'ج', 'د'][i] : '${i + 1}',
                  String.fromCharCode(65 + i),
                ),
                onPressed: !_enabled
                    ? null
                    : () {
                        setState(() => _choice = widget.question.options[i].id);
                        widget.onDraftChanged?.call(_answer);
                      },
              ),
          ],
        ),
        QuizQuestionType.trueFalse => Column(
          children: [
            for (final value in [true, false])
              _QuizChoice(
                selected: _boolean == value,
                label: context.tr(value ? 'صح' : 'خطأ'),
                onPressed: !_enabled
                    ? null
                    : () {
                        setState(() => _boolean = value);
                        widget.onDraftChanged?.call(_answer);
                      },
              ),
          ],
        ),
        QuizQuestionType.numeric => Column(
          children: [
            TextField(
              key: Key('quiz-number'),
              controller: _value,
              enabled: _enabled,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr('القيمة'),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              key: Key('quiz-unit'),
              controller: _unit,
              enabled: _enabled,
              decoration: InputDecoration(
                labelText: context.tr('الوحدة'),
                helperText: context.tr(
                  'استخدم الوحدة المطلوبة في السؤال، أو اتركها فارغة للكمية بلا وحدة.',
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        QuizQuestionType.shortAnswer => TextField(
          key: Key('quiz-short-answer'),
          controller: _short,
          enabled: _enabled,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.tr('إجابتك'),
            border: OutlineInputBorder(),
          ),
        ),
      },
      SizedBox(height: 16),
      if (widget.feedback == null && widget.onDraftChanged == null)
        FilledButton(
          key: Key('quiz-submit'),
          onPressed: _enabled && _answer != null
              ? () => widget.onAnswer(_answer!)
              : null,
          child: Text(context.tr('تحقق من الإجابة')),
        ),
      if (widget.feedback case final feedback?)
        QuizFeedbackCard(feedback: feedback),
    ],
  );
}

class QuizFeedbackCard extends StatelessWidget {
  const QuizFeedbackCard({super.key, required this.feedback});
  final QuizFeedback feedback;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (feedback.verdict) {
            QuizVerdict.correct => context.tr('إجابة صحيحة'),
            QuizVerdict.incorrect => context.tr('إجابة غير صحيحة'),
            QuizVerdict.undetermined => context.tr('تعذر الحكم'),
          }, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(context.tr(feedback.explanation)),
        ],
      ),
    ),
  );
}

class QuizSummaryView extends StatelessWidget {
  const QuizSummaryView({super.key, required this.summary});
  final QuizSummary summary;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SirajStatusPill(
            text: context.copy('نتيجة الجلسة', 'Session result'),
            tone: SirajPillTone.good,
          ),
        ),
        Center(
          child: Container(
            key: const Key('quiz-result-ring'),
            width: 113,
            height: 113,
            margin: const EdgeInsets.only(top: 14, bottom: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 9,
                color: c.secondary.withValues(alpha: .35),
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${summary.correct} / ${summary.judgeable}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.copy('قابل للتقييم', 'Judgeable'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            context.copy(
              '${summary.judgeable} أسئلة محسومة. الإجابات غير المحسومة خارج المقام.',
              '${summary.judgeable} judgeable questions. Undetermined answers are excluded.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SirajCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.copy(
                        '${summary.correct} صحيحة',
                        '${summary.correct} correct',
                      ),
                      style: TextStyle(
                        color: c.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.copy(
                        '${summary.incorrect} خاطئة',
                        '${summary.incorrect} incorrect',
                      ),
                      style: TextStyle(
                        color: c.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.copy(
                        '${summary.undetermined} تعذر الحكم',
                        '${summary.undetermined} undetermined',
                      ),
                    ),
                  ),
                  SirajStatusPill(
                    text: context.copy('خارج المقام', 'Excluded'),
                    warning: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        SirajReferenceNotice(
          icon: Icons.shield_outlined,
          text: context.copy(
            'الإجابات التي تعذر الحكم عليها ليست أخطاء. تبقى النتيجة في الجلسة الحالية فقط، وتُمحى عند إنهائها.',
            'Undetermined answers are not errors. Results remain only in this session and are cleared when it ends.',
          ),
        ),
      ],
    );
  }
}

class _QuizChoice extends StatelessWidget {
  const _QuizChoice({
    super.key,
    required this.selected,
    required this.label,
    required this.onPressed,
    this.marker,
  });
  final bool selected;
  final String label;
  final String? marker;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        enabled: onPressed != null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? c.primaryContainer : c.surface,
            foregroundColor: selected ? c.primary : c.onSurface,
            side: BorderSide(color: selected ? c.primary : c.outlineVariant),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            textStyle: TextStyle(
              fontFamily: 'NotoSansArabic',
              fontSize: 11,
              height: 2.1,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
          child: Row(
            children: [
              if (marker != null) ...[
                SizedBox(width: 20, child: Text(marker!)),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}
