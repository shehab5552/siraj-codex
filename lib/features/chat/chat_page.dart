import 'package:flutter/material.dart';

/// The B-02 chat UI is intentionally non-functional.
/// Messages must not be sent/saved until the real DB and service contracts exist.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثة — معاينة B-02')),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'هذه معاينة لشاشة المحادثة فقط. '
                    'لا توجد إجابات مولدة أو مصادر أو محادثات محفوظة بعد.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'الإرسال غير متاح حتى تنفيذ الحفظ الذري '
                'وعقود Tutor الحقيقية.',
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat-question-input'),
                      controller: _questionController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'اكتب سؤالًا (معاينة فقط)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const IconButton(
                    key: Key('chat-send-disabled'),
                    onPressed: null,
                    tooltip: 'الإرسال غير متاح بعد',
                    icon: Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
