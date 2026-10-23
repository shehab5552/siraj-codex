import 'package:flutter/material.dart';
import '../../integrations/ai/quiz_port.dart';
import 'quiz_controller.dart';

String quizErrorText(QuizErrorCode code) => switch (code) {
  QuizErrorCode.modelRequired =>
    'النموذج المحلي غير جاهز لتوليد الاختبار. جهّز الموارد ثم أعد المحاولة.',
  QuizErrorCode.notAvailable =>
    'الاختبار غير متاح بالموارد أو العدد المطلوب حاليًا.',
  QuizErrorCode.generationRejected =>
    'لم ينتج المعلّم أسئلة اجتازت التحقق. يمكنك إعادة المحاولة.',
  QuizErrorCode.invalidResponse =>
    'تعذر عرض الاختبار لأن بياناته لم تجتز التحقق.',
  QuizErrorCode.requestCancelled => 'أُلغي طلب الاختبار.',
  QuizErrorCode.sessionExpired => 'انتهت صلاحية الجلسة. يلزم تسجيل الدخول.',
  QuizErrorCode.invalidInput =>
    'راجع الإجابة أو عدد الأسئلة المدخل قبل المتابعة.',
  QuizErrorCode.runtimeFailed =>
    'تعذر إكمال العملية بأمان. أعد المحاولة لاحقًا.',
};

class QuizRequestForm extends StatefulWidget {
  const QuizRequestForm({super.key, required this.onStart, required this.busy});
  final void Function(
    String text, {
    int? desiredCount,
    QuizQuestionType? desiredType,
  })
  onStart;
  final bool busy;
  @override
  State<QuizRequestForm> createState() => _QuizRequestFormState();
}

class _QuizRequestFormState extends State<QuizRequestForm> {
  final _form = GlobalKey<FormState>();
  final _request = TextEditingController(), _count = TextEditingController();
  QuizQuestionType? _type;
  @override
  void dispose() {
    _request.dispose();
    _count.dispose();
    super.dispose();
  }

  String _digits(String text) => String.fromCharCodes(
    text.trim().runes.map(
      (c) => c >= 0x660 && c <= 0x669
          ? c - 0x660 + 0x30
          : c >= 0x6f0 && c <= 0x6f9
          ? c - 0x6f0 + 0x30
          : c,
    ),
  );
  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختبر فهمك',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'اطلب اختبارًا في درس أو وحدة. تُولد الأسئلة محليًا بعد جاهزية الموارد والتحقق منها. لا تُحفظ نتيجة الاختبار بعد إنهائه.',
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('quiz-request'),
          controller: _request,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ما الذي تريد التدرب عليه؟',
            border: OutlineInputBorder(),
          ),
          validator: (s) =>
              s == null || s.trim().isEmpty ? 'اكتب طلب الاختبار.' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<QuizQuestionType>(
          key: const Key('quiz-request-type'),
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'نوع الأسئلة',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('أنواع متنوعة')),
            for (final type in QuizQuestionType.values)
              DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
          ],
          onChanged: widget.busy
              ? null
              : (value) => setState(() => _type = value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('quiz-count'),
          controller: _count,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عدد الأسئلة (اختياري)',
            border: OutlineInputBorder(),
          ),
          validator: (s) {
            if (s == null || s.trim().isEmpty) return null;
            final value = int.tryParse(_digits(s));
            return value == null || value <= 0
                ? 'أدخل عددًا صحيحًا موجبًا.'
                : null;
          },
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('quiz-start'),
          onPressed: widget.busy
              ? null
              : () {
                  if (_form.currentState!.validate()) {
                    widget.onStart(
                      _request.text,
                      desiredCount: _count.text.trim().isEmpty
                          ? null
                          : int.parse(_digits(_count.text)),
                      desiredType: _type,
                    );
                  }
                },
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('إنشاء الاختبار'),
        ),
      ],
    ),
  );
  String _typeLabel(QuizQuestionType type) => switch (type) {
    QuizQuestionType.mcq => 'اختيار من متعدد',
    QuizQuestionType.trueFalse => 'صح أو خطأ',
    QuizQuestionType.numeric => 'مسألة عددية',
    QuizQuestionType.shortAnswer => 'إجابة قصيرة',
  };
}

class QuizQuestionForm extends StatefulWidget {
  const QuizQuestionForm({
    super.key,
    required this.question,
    required this.feedback,
    required this.onAnswer,
    required this.busy,
  });
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
      const SizedBox(height: 16),
      switch (widget.question.type) {
        QuizQuestionType.mcq => RadioGroup<String>(
          groupValue: _choice,
          onChanged: (value) {
            if (_enabled) setState(() => _choice = value);
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
            if (_enabled) setState(() => _boolean = value);
          },
          child: Column(
            children: [
              RadioListTile<bool>(
                value: true,
                title: const Text('صح'),
                enabled: _enabled,
              ),
              RadioListTile<bool>(
                value: false,
                title: const Text('خطأ'),
                enabled: _enabled,
              ),
            ],
          ),
        ),
        QuizQuestionType.numeric => Column(
          children: [
            TextField(
              key: const Key('quiz-number'),
              controller: _value,
              enabled: _enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'القيمة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quiz-unit'),
              controller: _unit,
              enabled: _enabled,
              decoration: const InputDecoration(
                labelText: 'الوحدة',
                helperText:
                    'استخدم الوحدة المطلوبة في السؤال، أو اتركها فارغة للكمية بلا وحدة.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        QuizQuestionType.shortAnswer => TextField(
          key: const Key('quiz-short-answer'),
          controller: _short,
          enabled: _enabled,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'إجابتك',
            border: OutlineInputBorder(),
          ),
        ),
      },
      const SizedBox(height: 16),
      if (widget.feedback == null)
        FilledButton(
          key: const Key('quiz-submit'),
          onPressed: _enabled && _answer != null
              ? () => widget.onAnswer(_answer!)
              : null,
          child: const Text('تحقق من الإجابة'),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (feedback.verdict) {
            QuizVerdict.correct => 'إجابة صحيحة',
            QuizVerdict.incorrect => 'إجابة غير صحيحة',
            QuizVerdict.undetermined => 'تعذر الحكم',
          }, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(feedback.explanation),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'نتيجة الجلسة',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${summary.correct} صحيحة')),
              Chip(label: Text('${summary.incorrect} خاطئة')),
              Chip(label: Text('${summary.undetermined} تعذر الحكم')),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${summary.judgeable} أسئلة محسومة. الإجابات التي تعذر الحكم عليها ليست أخطاء.',
          ),
          const SizedBox(height: 12),
          const Text(
            'تبقى هذه النتيجة في الجلسة الحالية فقط، وتُمحى عند إنهائها.',
          ),
        ],
      ),
    ),
  );
}
