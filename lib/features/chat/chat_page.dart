import 'dart:async';

import 'package:flutter/material.dart';

import '../../integrations/ai/tutor_contract.dart';
import '../auth/auth_models.dart';
import 'chat_turn_coordinator.dart';
import 'chat_widgets.dart';
import 'conversation_draft_controller.dart';

/// Route owns its coordinator. The legacy draft entry remains supported;
/// composition supplies a real TutorPort later without changing this widget.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.coordinator,
    this.draftController,
    this.session,
  });
  final ChatTurnCoordinator? coordinator;
  final ConversationDraftController? draftController;
  final AuthSession? session;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatTurnCoordinator? _chat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(_inputChanged);
    _bind();
  }

  void _bind() {
    _chat =
        widget.coordinator ??
        (widget.draftController != null && widget.session != null
            ? ChatTurnCoordinator.fromDraft(
                widget.draftController!,
                widget.session!,
              )
            : null);
    _chat?.addListener(_changed);
    unawaited(_chat?.initialize());
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.draftController != widget.draftController ||
        oldWidget.session != widget.session) {
      _chat?.removeListener(_changed);
      _chat?.dispose();
      _input.clear();
      _bind();
    }
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    if (_chat?.phase == ChatPhase.sessionExpired) _input.clear();
    final chat = _chat;
    final showEvictionNotice = chat?.takeEvictionNotice() == true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(chat, _chat) &&
          chat?.phase != ChatPhase.sessionExpired &&
          showEvictionNotice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'حُذفت أقدم محادثة بعد حفظ سؤالك؛ يُحفظ آخر عشر محادثات.',
            ),
          ),
        );
      }
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_chat?.refresh());
    }
  }

  Future<void> _send() async {
    final chat = _chat;
    if (chat == null) return;
    await chat.send(_input.text);
    if (mounted && chat.lastUserMessageSaved) {
      _input.clear();
    }
  }

  Future<void> _retry() async {
    final chat = _chat;
    if (chat == null) return;
    await chat.retry();
    if (mounted && chat.lastUserMessageSaved) _input.clear();
  }

  void _openSource(SourceReference reference) {
    final chat = _chat;
    if (chat == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChatSourceSheet(coordinator: chat, reference: reference),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat?.removeListener(_changed);
    _chat?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final enabled = chat?.canSend == true;
    final canSend = enabled && _input.text.trim().isNotEmpty;
    final messages = chat?.messages ?? const <ChatMessage>[];
    var assistantIndex = 0;
    final firstUserIndex = messages.indexWhere((message) => message.isUser);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحادثة'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(22),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'سراج — المعلم المحلي',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (chat != null && !chat.availability.isReady)
                const ChatReadinessNotice(key: Key('chat-no-ai-answer')),
              Expanded(
                child: ListView(
                  key: const Key('chat-message-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              chat == null
                                  ? 'يلزم تسجيل دخول صالح لفتح محادثاتك وإرسال الأسئلة.'
                                  : chat.phase == ChatPhase.sessionExpired
                                  ? 'المحادثة غير متاحة لهذه الجلسة.'
                                  : 'محادثة جديدة مؤقتة. تُحفظ عند إرسال أول سؤال صالح.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    for (var i = 0; i < messages.length; i++)
                      ChatMessageBubble(
                        key: i == firstUserIndex
                            ? const Key('chat-saved-question')
                            : Key('chat-message-${messages[i].id}'),
                        message: messages[i],
                        assistantIndex: messages[i].isUser
                            ? -1
                            : assistantIndex++,
                        onSource: _openSource,
                        partial:
                            !messages[i].isUser &&
                            i == messages.length - 1 &&
                            chat?.lastResult?.isPartial == true,
                      ),
                    if (chat?.failure != null)
                      ChatFailureNotice(
                        key: const Key('chat-save-error'),
                        failure: chat!.failure!,
                        onRetry: chat.canRetry
                            ? () => unawaited(_retry())
                            : null,
                      ),
                    if (chat?.isBusy == true)
                      Semantics(
                        liveRegion: true,
                        child: Card(
                          key: const Key('chat-loading'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const LinearProgressIndicator(),
                                const SizedBox(height: 10),
                                Text(
                                  chat!.phase == ChatPhase.asking
                                      ? 'جارٍ إعداد الإجابة…'
                                      : chat.phase == ChatPhase.loading
                                      ? 'جارٍ فتح المحادثة…'
                                      : 'جارٍ حفظ الرسالة…',
                                ),
                                if (chat.phase != ChatPhase.loading)
                                  TextButton.icon(
                                    key: const Key('chat-cancel'),
                                    onPressed: () => unawaited(chat.cancel()),
                                    icon: const Icon(Icons.close),
                                    label: const Text('إلغاء'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat-question-input'),
                        controller: _input,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'اكتب سؤالك أو رسالة متابعة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: Key(
                        canSend ? 'chat-send-enabled' : 'chat-send-disabled',
                      ),
                      onPressed: canSend ? () => unawaited(_send()) : null,
                      tooltip: 'إرسال السؤال',
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
