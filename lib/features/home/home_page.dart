import 'package:flutter/material.dart';

import '../../app/app_routes.dart';

/// Debug-only preview; it is not a signed-in application home screen.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معاينة هندسية — B-02',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'هذه الواجهة متاحة في وضع Debug فقط. '
                      'لم تُنفذ المصادقة أو SQLite أو Local AI/RAG بعد. '
                      'ولا تمثل النسخة الإنتاجية من سراج.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('open-chat'),
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.chat),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('فتح معاينة المحادثة'),
            ),
            const SizedBox(height: 12),
            const Text(
              'سيُربط زر الإرسال بحفظ الرسائل وخدمة Tutor '
              'بعد تنفيذ B-05 وB-08 وB-09.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
