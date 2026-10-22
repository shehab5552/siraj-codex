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
        MaterialPageRoute(builder: (_) => ChatPage(coordinator: chat)),
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
    textDirection: TextDirection.rtl,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final history = widget.controller;
        return Scaffold(
          appBar: AppBar(
            title: const Text('محادثاتك'),
            actions: [
              IconButton(
                tooltip: 'تحديث المحادثات',
                onPressed: history.isLoading
                    ? null
                    : () => unawaited(history.load()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'تابع أسئلتك من حيث توقفت',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'تُحفظ حتى عشر محادثات على هذا الجهاز. عند حفظ أول رسالة صالحة في المحادثة الحادية عشرة، تُحذف أقدم محادثة تلقائيًا.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('history-new-chat'),
                  onPressed:
                      _opening || history.isLoading || history.sessionExpired
                      ? null
                      : () => unawaited(_open()),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('محادثة جديدة'),
                ),
                if (history.isLoading)
                  const Padding(
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
                  const Padding(
                    key: Key('history-empty'),
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'لا توجد محادثات محفوظة بعد.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final item in history.conversations)
                  Card(
                    child: ListTile(
                      key: Key('history-${item.id}'),
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: _opening ? null : () => unawaited(_open(item.id)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
