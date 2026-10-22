import 'package:flutter/material.dart';

import '../../app/app_routes.dart';

/// Debug preview when [onOpenChat] is null; otherwise entered only after
/// validating the encrypted marker and its matching SQLite nonce.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.onOpenChat,
    this.onOpenResources,
    this.onOpenHistory,
  });

  final VoidCallback? onOpenChat;

  /// Supplied only from an authenticated bootstrap. Never use it in preview.
  final VoidCallback? onOpenResources;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final authenticated = onOpenChat != null;
    return Scaffold(
      appBar: AppBar(title: const Text('سراج')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.school_outlined, size: 68),
            const SizedBox(height: 12),
            const Text(
              'سراج — المعلم المحلي',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authenticated
                          ? 'جلسة محلية موثّقة'
                          : 'معاينة هندسية — Debug',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authenticated
                          ? 'أسئلتك ومحادثاتك محفوظة محليًا. '
                                'تتوفر الإجابات عند جاهزية موارد المعلم المحلي.'
                          : 'واجهة معاينة فقط. SQLite والمصادقة بُنيت أجزاء منهما، '
                                'لكن لا توجد جلسة موثّقة في هذه المعاينة، '
                                'ولذلك إرسال المحادثة معطّل.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('open-chat'),
              onPressed:
                  onOpenChat ??
                  () => Navigator.of(context).pushNamed(AppRoutes.chat),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(
                authenticated ? 'فتح المحادثة' : 'فتح معاينة المحادثة',
              ),
            ),
            if (authenticated && onOpenResources != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-resource-status'),
                onPressed: onOpenResources,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('حالة الموارد'),
              ),
            ],
            if (authenticated && onOpenHistory != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-chat-history'),
                onPressed: onOpenHistory,
                icon: const Icon(Icons.history),
                label: const Text('محادثاتي المحفوظة'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'تبقى المحادثات على جهازك. تعمل الوظائف التعليمية دون شبكة بعد تجهيز مواردها.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
