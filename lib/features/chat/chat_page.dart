import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_v2_icons.dart';
import '../../core/design/siraj_v2_illustration.dart';
import '../../core/localization/siraj_copy.dart';
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
    this.onOpenHistory,
  });
  final ChatTurnCoordinator? coordinator;
  final ConversationDraftController? draftController;
  final AuthSession? session;
  final VoidCallback? onOpenHistory;
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
          SnackBar(
            content: Text(
              context.tr(
                'حُذفت أقدم محادثة بعد حفظ سؤالك؛ يُحفظ آخر عشر محادثات.',
              ),
            ),
          ),
        );
      }
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: Duration(milliseconds: 180),
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
    final messages = chat?.messages ?? <ChatMessage>[];
    var assistantIndex = 0;
    final firstUserIndex = messages.indexWhere((message) => message.isUser);
    return Directionality(
      textDirection: SirajCopy.isArabic(context)
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: SirajAppBar(
          title: context.copy('المساعد التعليمي', 'Learning assistant'),
          subtitle: context.copy(
            chat?.conversationId == null
                ? 'محادثة جديدة Draft مؤقتة'
                : 'محادثة محفوظة على الجهاز',
            chat?.conversationId == null
                ? 'New temporary draft'
                : 'Conversation saved on device',
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: Key('chat-message-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
                  children: [
                    if (messages.isEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SirajStatusPill(
                                text: context.copy(
                                  'محادثة جديدة · مؤقتة',
                                  'New conversation · temporary',
                                ),
                                tone: SirajPillTone.good,
                              ),
                            ),
                          ),
                          if (widget.onOpenHistory != null)
                            TextButton.icon(
                              key: const Key('chat-history'),
                              onPressed: widget.onOpenHistory,
                              icon: const SirajV2Icon('history', size: 18),
                              label: Text(
                                context.copy('سجل المحادثات', 'History'),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 52, 7, 18),
                        child: Column(
                          children: [
                            const SirajV2Illustration(
                              key: Key('v2-chat-illustration'),
                              icon: 'message',
                              compact: true,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.copy(
                                'ما الذي تريد فهمه اليوم؟',
                                'What would you like to understand today?',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              chat == null
                                  ? context.tr(
                                      'يلزم تسجيل دخول صالح لفتح محادثاتك وإرسال الأسئلة.',
                                    )
                                  : chat.phase == ChatPhase.sessionExpired
                                  ? context.tr(
                                      'المحادثة غير متاحة لهذه الجلسة.',
                                    )
                                  : context.copy(
                                      'اكتب سؤالك، وستبدأ المحادثة عند إرسال أول رسالة صحيحة فقط.',
                                      'Write your question. A conversation starts only after the first valid message.',
                                    ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 11, height: 1.9),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (chat != null && !chat.availability.isReady)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 11),
                        child: ChatReadinessNotice(
                          key: Key('chat-no-ai-answer'),
                        ),
                      ),
                    for (var i = 0; i < messages.length; i++)
                      ChatMessageBubble(
                        key: i == firstUserIndex
                            ? Key('chat-saved-question')
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
                        key: Key('chat-save-error'),
                        failure: chat!.failure!,
                        onRetry: chat.canRetry
                            ? () => unawaited(_retry())
                            : null,
                      ),
                    if (chat?.isBusy == true)
                      Semantics(
                        liveRegion: true,
                        child: Card(
                          key: Key('chat-loading'),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              children: [
                                LinearProgressIndicator(),
                                SizedBox(height: 10),
                                Text(
                                  chat!.phase == ChatPhase.asking
                                      ? context.tr('جارٍ إعداد الإجابة…')
                                      : chat.phase == ChatPhase.loading
                                      ? context.tr('جارٍ فتح المحادثة…')
                                      : context.tr('جارٍ حفظ الرسالة…'),
                                ),
                                if (chat.phase != ChatPhase.loading)
                                  TextButton.icon(
                                    key: Key('chat-cancel'),
                                    onPressed: () => unawaited(chat.cancel()),
                                    icon: Icon(Icons.close),
                                    label: Text(context.tr('إلغاء')),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                key: const Key('v2-chat-composer'),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('chat-question-input'),
                        controller: _input,
                        enabled: enabled,
                        style: const TextStyle(fontSize: 11, height: 1.9),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: context.tr('اكتب سؤالك أو رسالة متابعة'),
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 10,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(48, 48),
                      ),
                      key: Key(
                        canSend ? 'chat-send-enabled' : 'chat-send-disabled',
                      ),
                      onPressed: canSend ? () => unawaited(_send()) : null,
                      tooltip: context.tr('إرسال السؤال'),
                      icon: const SirajV2Icon('send', size: 18),
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
