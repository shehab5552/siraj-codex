import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_components.dart';
import '../../core/design/siraj_v2_icons.dart';
import '../../core/localization/siraj_copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'chat_widgets.dart';
import 'conversation_history_controller.dart';

class ConversationHistoryPage extends StatefulWidget {
  const ConversationHistoryPage({super.key, required this.controller});
  final ConversationHistoryController controller;
  @override
  State<ConversationHistoryPage> createState() =>
      _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.load());
  }

  @override
  void didUpdateWidget(covariant ConversationHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.dispose();
      _opening = false;
      unawaited(widget.controller.load());
    }
  }

  Future<void> _open([String? id]) async {
    if (_opening) return;
    setState(() => _opening = true);
    final history = widget.controller;
    final chat = id == null
        ? await history.openDraft()
        : await history.openConversation(id);
    if (!mounted || !identical(history, widget.controller)) {
      chat?.dispose();
      return;
    }
    if (chat != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            coordinator: chat,
            onOpenHistory: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
    if (mounted && identical(history, widget.controller)) {
      await history.load();
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: SirajCopy.isArabic(context)
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final history = widget.controller;
        return Scaffold(
          appBar: SirajAppBar(
            title: context.copy('سجل المحادثات', 'Conversation history'),
            subtitle: context.copy(
              'حتى عشر محادثات محفوظة',
              'Up to ten saved conversations',
            ),
            actions: [
              IconButton(
                tooltip: context.tr('تحديث المحادثات'),
                onPressed: history.isLoading
                    ? null
                    : () => unawaited(history.load()),
                icon: Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('محادثاتك'),
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontSize: 13),
                            ),
                            Text(
                              context.copy(
                                'تُحفظ بعد أول رسالة صحيحة',
                                'Saved after the first valid message',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      SirajStatusPill(
                        text: context.copy(
                          '${history.conversations.length} من 10',
                          '${history.conversations.length} of 10',
                        ),
                        tone: SirajPillTone.gray,
                      ),
                    ],
                  ),
                ),
                if (history.isLoading)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (history.failure != null)
                  ChatFailureNotice(
                    failure: history.failure!,
                    onRetry: history.sessionExpired
                        ? null
                        : () => unawaited(history.load()),
                  ),
                if (!history.isLoading &&
                    history.conversations.isEmpty &&
                    !history.sessionExpired)
                  Padding(
                    key: Key('history-empty'),
                    padding: EdgeInsets.all(32),
                    child: Text(
                      context.tr('لا توجد محادثات محفوظة بعد.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final item in history.conversations)
                  SirajCard(
                    child: InkWell(
                      key: Key('history-${item.id}'),
                      onTap: _opening ? null : () => unawaited(_open(item.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const SirajIconTile(
                                icon: Icons.chat_bubble_outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontSize: 11),
                                    ),
                                    Text(
                                      context.copy(
                                        'محادثة محفوظة على هذا الجهاز',
                                        'Saved on this device',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              key: Key('history-open-${item.id}'),
                              onPressed: _opening
                                  ? null
                                  : () => unawaited(_open(item.id)),
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: Text(context.copy('فتح', 'Open')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SirajReferenceNotice(
                  key: const Key('v2-history-retention'),
                  text: context.copy(
                    'يُحذف الأقدم تلقائيًا عند تجاوز عشر محادثات، داخل معاملة آمنة وفق مواصفة P0.',
                    'The oldest conversation is removed automatically when exceeding ten, inside a safe transaction under P0.',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('history-new-chat'),
                  onPressed:
                      _opening || history.isLoading || history.sessionExpired
                      ? null
                      : () => unawaited(_open()),
                  icon: const SirajV2Icon('message', size: 18),
                  label: Text(context.tr('محادثة جديدة')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
