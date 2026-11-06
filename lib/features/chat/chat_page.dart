import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import 'conversation_draft_controller.dart';
import 'chat_turn_coordinator.dart';
import 'tutor_contracts.dart';
import 'package:uuid/uuid.dart';

/// B-05: view-only by default; enabled only when a verified session and
/// a session-guarded draft controller are supplied by the authenticated flow.
/// The debug B-02 route supplies neither, so it cannot create DB rows.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.draftController, this.session, this.turns});

  final ConversationDraftController? draftController;
  final AuthSession? session;
  final ChatTurnCoordinator? turns;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _questionController = TextEditingController();
  bool _busy = false;
  String? _savedQuestion;
  String? _error;
  final List<Widget> _turnMessages = [];

  bool get _hasSession =>
      widget.draftController != null && widget.session != null;

  bool get _canSend =>
      _hasSession &&
      (widget.turns != null || widget.draftController!.isTemporary) &&
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
      if (widget.turns != null) {
        final result = await widget.turns!.send(
          session: widget.session!,
          question: question,
          turnId: const Uuid().v4(),
        );
        if (!mounted) return;
        setState(() {
          _turnMessages.add(
            Align(
              alignment: Alignment.centerRight,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(question),
                ),
              ),
            ),
          );
          _turnMessages.add(TutorResultView(result: result.result));
          _questionController.clear();
        });
        return;
      }
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
    widget.turns?.dispose();
    _questionController.removeListener(_updateSubmitState);
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _canSend;
    final isSaved = widget.draftController?.isTemporary == false;
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثة')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('chat-message-list'),
                padding: const EdgeInsets.all(20),
                children: [
                  ..._turnMessages,
                  if (_savedQuestion == null && _turnMessages.isEmpty)
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
                  if (isSaved && widget.turns == null)
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
                isSaved && widget.turns == null
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
                      enabled:
                          _hasSession &&
                          (widget.turns != null || !isSaved) &&
                          !_busy,
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
                  if (_busy && widget.turns != null)
                    IconButton(
                      key: const Key('chat-cancel'),
                      tooltip: 'إلغاء',
                      onPressed: widget.turns!.cancel,
                      icon: const Icon(Icons.stop_circle_outlined),
                    ),
                  IconButton(
                    key: Key(
                      canSubmit ? 'chat-send-enabled' : 'chat-send-disabled',
                    ),
                    onPressed: canSubmit ? _submitFirstQuestion : null,
                    tooltip: canSubmit ? 'إرسال السؤال' : 'الإرسال غير متاح',
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

/// Presentation only; no native calls, source invention or database writes.
class TutorResultView extends StatelessWidget {
  const TutorResultView({super.key, required this.result});
  final TutorResult result;
  @override
  Widget build(BuildContext context) {
    if (result.status == TutorStatus.answer) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.text),
              if (result.isPartial)
                const Text('إجابة جزئية — بعض المطالب غير مدعومة.'),
              for (final source in result.sources)
                Text(
                  'المصدر: ${source.packId} / ${source.chunkId} · ${source.datasetRevision}',
                ),
            ],
          ),
        ),
      );
    }
    final message = switch (result.reason) {
      TutorReason.noEvidence => 'لا توجد أدلة كافية لإجابة موثوقة.',
      TutorReason.cancelled => 'أُلغي الطلب. لم تُحفظ إجابة.',
      TutorReason.sessionInvalid => 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
      TutorReason.sourceUnavailable =>
        'مصدر الإجابة غير متاح أو تغيّر إصدار البيانات.',
      TutorReason.resourcesUnavailable =>
        'موارد المعلّم الموثوقة غير جاهزة بعد. حُفظ سؤالك محليًا.',
      _ => 'تعذّر إكمال الإجابة. لم تُعرض نتيجة غير متحققة.',
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(message, key: const Key('tutor-operational-status')),
    );
  }
}
