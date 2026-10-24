import '../../core/localization/siraj_copy.dart';
import 'package:flutter/material.dart';

import '../../integrations/ai/tutor_contract.dart';
import '../../integrations/ai/tutor_port.dart';
import 'chat_copy.dart';
import 'chat_turn_coordinator.dart';

class ChatReadinessNotice extends StatelessWidget {
  const ChatReadinessNotice({super.key});
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr(
                'الذكاء الاصطناعي غير جاهز حاليًا. يمكنك حفظ أسئلتك محليًا.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ChatFailureNotice extends StatelessWidget {
  const ChatFailureNotice({super.key, required this.failure, this.onRetry});
  final ChatFailure failure;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 10),
                Expanded(child: Text(context.tr(chatFailureText(failure)))),
              ],
            ),
            if (onRetry != null)
              TextButton.icon(
                key: Key('chat-retry'),
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text(context.tr('إعادة المحاولة')),
              ),
          ],
        ),
      ),
    ),
  );
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.assistantIndex,
    required this.onSource,
    this.partial = false,
  });
  final ChatMessage message;
  final int assistantIndex;
  final ValueChanged<SourceReference> onSource;
  final bool partial;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: message.isUser
                ? colors.primaryContainer
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.isUser ? context.tr('أنت') : context.tr('سراج'),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
              SizedBox(height: 8),
              if (partial)
                Padding(
                  key: Key('chat-partial'),
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr('إجابة جزئية'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              SelectableText(message.text),
              if (message.sourcesUnavailable)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(context.tr('المصادر المسجلة غير متاحة.')),
                ),
              if (message.sources.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < message.sources.length; i++)
                        ActionChip(
                          key: Key('chat-source-$assistantIndex-$i'),
                          avatar: Icon(Icons.menu_book_outlined, size: 18),
                          label: Text(
                            context.copy('المصدر ${i + 1}', 'Source ${i + 1}'),
                          ),
                          onPressed: () => onSource(message.sources[i]),
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

class ChatSourceSheet extends StatefulWidget {
  const ChatSourceSheet({
    super.key,
    required this.coordinator,
    required this.reference,
  });
  final ChatTurnCoordinator coordinator;
  final SourceReference reference;
  @override
  State<ChatSourceSheet> createState() => _ChatSourceSheetState();
}

class _ChatSourceSheetState extends State<ChatSourceSheet> {
  late final Future<ResolvedSource?> _source = widget.coordinator.resolveSource(
    widget.reference,
  );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: SirajCopy.isArabic(context)
        ? TextDirection.rtl
        : TextDirection.ltr,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: AnimatedBuilder(
          animation: widget.coordinator,
          builder: (context, _) {
            if (widget.coordinator.phase == ChatPhase.sessionExpired) {
              return Text(context.tr('انتهت الجلسة. المصدر غير متاح.'));
            }
            return FutureBuilder<ResolvedSource?>(
              future: _source,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final source = snapshot.data;
                if (source == null) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      context.tr('المصدر غير متاح لهذه الإجابة حاليًا.'),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .7,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('مصدر الإجابة'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 12),
                        for (final label in [
                          source.subject,
                          source.unit,
                          source.lesson,
                          source.document,
                        ])
                          if (label != null && label.trim().isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(label),
                            ),
                        if (source.page != null)
                          Text(
                            context.copy(
                              'صفحة ${source.page}',
                              'Page ${source.page}',
                            ),
                          ),
                        Divider(),
                        SelectableText(source.snippet),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
