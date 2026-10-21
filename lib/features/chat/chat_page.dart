import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import 'conversation_draft_controller.dart';

/// B-05: view-only by default; enabled only when a verified session and
/// a session-guarded draft controller are supplied by the authenticated flow.
/// The debug B-02 route supplies neither, so it cannot create DB rows.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.draftController, this.session});

  final ConversationDraftController? draftController;
  final AuthSession? session;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _questionController = TextEditingController();
  bool _busy = false;
  String? _savedQuestion;
  String? _error;

  bool get _hasSession =>
      widget.draftController != null && widget.session != null;

  bool get _canSend =>
      _hasSession &&
      widget.draftController!.isTemporary &&
      !_busy &&
      _questionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(_updateSubmitState);
  }

  void _updateSubmitState() {
    if (mounted) setState(() {});
  }

  Future<void> _submitFirstQuestion() async {
    if (!_canSend) return;
    final question = _questionController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.draftController!.commitFirstQuestion(
        session: widget.session!,
        question: question,
      );
      if (!mounted) return;
      setState(() {
        _savedQuestion = question;
        _questionController.clear();
      });
    } on AuthFailure {
      if (!mounted) return;
      setState(
        () => _error = 'انتهت الجلسة أو لم تعد صالحة. سجّل الدخول مرة أخرى.',
      );
    } on Exception {
      if (!mounted) return;
      setState(
        () => _error =
            'تعذّر حفظ السؤال. لم نعرض إجابة ولم ننفّذ طلبًا إلى الذكاء الاصطناعي.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _questionController.removeListener(_updateSubmitState);
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _canSend;
    final isSaved = widget.draftController?.isTemporary == false;
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثة — B-05')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('chat-message-list'),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_savedQuestion == null)
                    Text(
                      _hasSession
                          ? 'محادثة جديدة مؤقتة. لا تُحفظ حتى ترسل أول سؤال صالح.'
                          : 'معاينة واجهة المحادثة فقط. لا توجد جلسة مستخدم '
                                'موثقة في هذه الشاشة، ولذلك الإرسال معطل.',
                      textAlign: TextAlign.center,
                    ),
                  if (_savedQuestion != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Card(
                        key: const Key('chat-saved-question'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_savedQuestion!),
                        ),
                      ),
                    ),
                  if (isSaved)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'تم حفظ السؤال محليًا. توليد الإجابات وإرسال أسئلة '
                        'إضافية غير مفعّلين حتى تكامل Tutor المعتمد.',
                        key: Key('chat-no-ai-answer'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        key: const Key('chat-save-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isSaved
                    ? 'هذه المرحلة تختبر حفظ أول رسالة فقط، دون توليد إجابات.'
                    : _hasSession
                    ? 'سيُحفظ السؤال الأول محليًا بعد التحقق من الجلسة.'
                    : 'الإرسال غير متاح حتى ربط الحساب والجلسة الآمنة.',
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
                      enabled: _hasSession && !isSaved && !_busy,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'اكتب سؤالك',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: Key(
                      canSubmit ? 'chat-send-enabled' : 'chat-send-disabled',
                    ),
                    onPressed: canSubmit ? _submitFirstQuestion : null,
                    tooltip: canSubmit
                        ? 'حفظ السؤال الأول'
                        : 'الإرسال غير متاح',
                    icon: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
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
