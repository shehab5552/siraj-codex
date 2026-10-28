import '../../core/design/siraj_v2_components.dart';
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
            title: context.tr('اختبر فهمك'),
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
                                  minimumSize: const Size(48, 70),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(switch (type) {
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
      Text(widget.question.stem, style: Theme.of(context).textTheme.titleLarge),
      SizedBox(height: 16),
      switch (widget.question.type) {
        QuizQuestionType.mcq => RadioGroup<String>(
          groupValue: _choice,
          onChanged: (value) {
            if (_enabled) {
              setState(() => _choice = value);
              widget.onDraftChanged?.call(_answer);
            }
          },
          child: Column(
            children: [
              for (final option in widget.question.options)
                RadioListTile<String>(
                  value: option.id,
                  title: Text(option.text),
                  enabled: _enabled,
                ),
            ],
          ),
        ),
        QuizQuestionType.trueFalse => RadioGroup<bool>(
          groupValue: _boolean,
          onChanged: (value) {
            if (_enabled) {
              setState(() => _boolean = value);
              widget.onDraftChanged?.call(_answer);
            }
          },
          child: Column(
            children: [
              RadioListTile<bool>(
                value: true,
                title: Text(context.tr('صح')),
                enabled: _enabled,
              ),
              RadioListTile<bool>(
                value: false,
                title: Text(context.tr('خطأ')),
                enabled: _enabled,
              ),
            ],
          ),
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
          maxLines: 3,
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('نتيجة الجلسة'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  context.copy(
                    '${summary.correct} صحيحة',
                    '${summary.correct} correct',
                  ),
                ),
              ),
              Chip(
                label: Text(
                  context.copy(
                    '${summary.incorrect} خاطئة',
                    '${summary.incorrect} incorrect',
                  ),
                ),
              ),
              Chip(
                label: Text(
                  context.copy(
                    '${summary.undetermined} تعذر الحكم',
                    '${summary.undetermined} undetermined',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            context.copy(
              '${summary.judgeable} أسئلة محسومة. الإجابات التي تعذر الحكم عليها ليست أخطاء.',
              '${summary.judgeable} judgeable questions. Undetermined answers are not counted as incorrect.',
            ),
          ),
          SizedBox(height: 12),
          Text(
            context.tr(
              'تبقى هذه النتيجة في الجلسة الحالية فقط، وتُمحى عند إنهائها.',
            ),
          ),
        ],
      ),
    ),
  );
}
