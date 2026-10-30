import 'package:flutter/material.dart';
import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_v2_illustration.dart';
import '../../core/design/siraj_v2_icons.dart';
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
    final slides = [
      (
        context.copy('معك خطوة بخطوة', 'With you, step by step'),
        context.copy(
          'فهم الدروس أصبح أوضح مع سراج، المساعد التعليمي للثالث الثانوي اليمني.',
          'Understand your lessons with SIRAJ, your Yemeni secondary school learning companion.',
        ),
        'sparkles',
      ),
      (
        context.copy('اسأل وتعلّم', 'Ask and learn'),
        context.copy(
          'اسأل عن أي درس، وتعرّف على المصادر التي يستند إليها التفسير.',
          'Ask about a lesson and explore the sources supporting its explanation.',
        ),
        'message',
      ),
      (
        context.copy('مكتبتك في هاتفك', 'Your library on your phone'),
        context.copy(
          'نزّل كتبك الرسمية وافتحها محليًا متى احتجت إليها.',
          'Download approved books and read them locally whenever you need them.',
        ),
        'book',
      ),
      (
        context.copy('اختبر فهمك', 'Check your understanding'),
        context.copy(
          'كوّن اختبارات قصيرة من دروسك بعد تجهيز النموذج المحلي.',
          'Create short quizzes from your lessons after preparing the local model.',
        ),
        'graduation',
      ),
    ];
    final slide = slides[_step];
    return Scaffold(
      appBar: SirajAppBar(
        title: context.copy('اكتشف سراج', 'Discover SIRAJ'),
        subtitle: context.copy('تعريف واضح بالمزايا', 'Explore the features'),
        showBack: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
              children: [
                const SizedBox(height: 27),
                SirajV2Illustration(icon: slide.$3),
                const SizedBox(height: 1),
                Center(
                  child: SirajStatusPill(
                    text: context.copy(
                      'تعلم أينما كنت',
                      'Learn wherever you are',
                    ),
                    tone: SirajPillTone.good,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  slide.$1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 21,
                    height: 2.1,
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  slide.$2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 15),
                Semantics(
                  label: context.copy(
                    'الخطوة ${_step + 1} من 4',
                    'Step ${_step + 1} of 4',
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Container(
                          width: i == _step ? 24 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          decoration: BoxDecoration(
                            color: i == _step
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (_failed)
                  SirajReferenceNotice(
                    text: context.copy(
                      'تعذر حفظ التفضيل. أعد المحاولة.',
                      'Could not save your preference. Please retry.',
                    ),
                    warning: true,
                  ),
                FilledButton(
                  key: const Key('onboarding-next'),
                  onPressed: _busy
                      ? null
                      : _step == 3
                      ? _complete
                      : () => setState(() => _step++),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _step == 3
                      ? Text(
                          context.copy(
                            'ابدأ استخدام سراج',
                            'Start using SIRAJ',
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(context.copy('التالي', 'Next')),
                            const SizedBox(width: 7),
                            const SirajV2Icon('arrow', size: 16),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 6),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 10,
                          height: 2.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              if (_step > 0) _step--;
                            }),
                      child: Text(context.tr('السابق')),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 6),
                        textStyle: const TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 10,
                          height: 2.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _busy ? null : _complete,
                      child: Text(context.copy('تخطي', 'Skip')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
