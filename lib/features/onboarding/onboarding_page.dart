import 'package:flutter/material.dart';
import '../../core/design/siraj_components.dart';
import '../../core/localization/siraj_copy.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});
  final Future<bool> Function() onComplete;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _busy = false, _failed = false;
  Future<void> _complete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await widget.onComplete();
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !saved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.copy('أهلًا بك في سراج', 'Welcome to SIRAJ'),
      context.copy('تعلم محليًا بخصوصية', 'Private, local learning'),
      context.copy('مصادر يمكن التحقق منها', 'Evidence you can verify'),
      context.copy('ابدأ رحلتك', 'Start your journey'),
    ];
    final messages = [
      context.copy(
        'مساعدك للدراسة والمراجعة، بتصميم بسيط وواضح.',
        'Your companion for studying and revision, with a clear and simple design.',
      ),
      context.copy(
        'حساب واحد على الجهاز. تبقى المحادثات محلية، ولا تتوفر استعادة لكلمة المرور المنسية.',
        'One account on this device. Conversations stay local. Forgotten passwords cannot be recovered.',
      ),
      context.copy(
        'تحتاج الإجابات والاختبارات إلى نموذج وبيانات تعليمية معتمدة ومتوافقة. لا يعرض سراج إجابات تجريبية عند غيابها.',
        'Answers and quizzes require approved, compatible models and educational resources. SIRAJ never supplies demo answers in their absence.',
      ),
      context.copy(
        'أنشئ حسابك المحلي ثم راجع حالة الموارد. تعمل الموارد المحملة والمعتمدة دون اتصال.',
        'Create your local account, then check resource status. Approved downloaded resources work offline.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('سراج')),
        actions: [
          TextButton(
            onPressed: _busy ? null : _complete,
            child: Text(context.copy('تخطي', 'Skip')),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Semantics(
                  label: context.copy(
                    'الخطوة ${_step + 1} من 4',
                    'Step ${_step + 1} of 4',
                  ),
                  child: LinearProgressIndicator(value: (_step + 1) / 4),
                ),
                const SizedBox(height: 32),
                Icon(
                  [
                    Icons.school_outlined,
                    Icons.phonelink_lock,
                    Icons.fact_check_outlined,
                    Icons.auto_awesome_outlined,
                  ][_step],
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  titles[_step],
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SirajCard(
                  child: Text(messages[_step], textAlign: TextAlign.center),
                ),
                const SizedBox(height: 24),
                if (_failed)
                  Text(
                    context.copy(
                      'تعذر حفظ التفضيل. أعد المحاولة.',
                      'Could not save your preference. Please retry.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: _busy
                      ? null
                      : _step == 3
                      ? _complete
                      : () => setState(() => _step++),
                  child: Text(
                    _step == 3 ? context.tr('ابدأ الآن') : context.tr('التالي'),
                  ),
                ),
                if (_step > 0)
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _step--),
                    child: Text(context.tr('السابق')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
