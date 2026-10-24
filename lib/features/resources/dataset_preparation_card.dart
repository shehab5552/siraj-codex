import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/resource_preparation_binding.dart';
import '../../app/presentation/siraj_problem.dart';
import '../../app/presentation/siraj_problem_card.dart';
import '../../core/localization/siraj_copy.dart';
import 'dataset_preparation.dart';

class DatasetPreparationCard extends StatefulWidget {
  const DatasetPreparationCard({super.key, required this.binding});
  final ResourcePreparationBinding binding;
  @override
  State<DatasetPreparationCard> createState() => _DatasetPreparationCardState();
}

class _DatasetPreparationCardState extends State<DatasetPreparationCard> {
  bool _consented = false, _confirming = false;
  Future<void> _start() async {
    if (widget.binding.coordinator.busy || _confirming) return;
    final binding = widget.binding;
    if (!_consented) {
      _confirming = true;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr('تجهيز الموارد')),
          content: SingleChildScrollView(
            child: Text(
              context.copy(
                'تجهيز Dataset عملية واحدة تشمل الحزم الخمس ونموذج Embedding المشترك. يلزم التخزين والاتصال للتنزيل الأول. يبقى الإصدار السابق محميًا حتى اكتمال فحص الإصدار الجديد وتفعيله.',
                'Dataset preparation is one operation for five packs and the shared Embedding model. The first download requires storage and connectivity. The previous revision remains protected until the new one is verified and activated.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('متابعة')),
            ),
          ],
        ),
      );
      _confirming = false;
      if (!mounted || !identical(binding, widget.binding) || accepted != true) {
        return;
      }
      _consented = true;
    }
    try {
      await binding.prepare(consented: true);
    } catch (_) {
      /* Typed coordinator state is the only error presentation source. */
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.binding.coordinator,
    builder: (context, _) {
      final c = widget.binding.coordinator;
      final phase = context.copy(
        switch (c.phase) {
          DatasetPreparationPhase.idle => 'جاهز لبدء التجهيز',
          DatasetPreparationPhase.preparing => 'جارٍ مراجعة الخطة والمساحة',
          DatasetPreparationPhase.downloading => 'جارٍ التنزيل',
          DatasetPreparationPhase.assembling => 'جارٍ تجميع الملفات',
          DatasetPreparationPhase.validating => 'جارٍ فحص السلامة والتوافق',
          DatasetPreparationPhase.activating => 'جارٍ حفظ مؤشر الإصدار ذريًا',
          DatasetPreparationPhase.active => 'اكتملت المعاملة الذرية للإصدار',
          DatasetPreparationPhase.cancelled => 'أُلغي التجهيز',
          DatasetPreparationPhase.failed => 'تعذّر التجهيز',
        },
        switch (c.phase) {
          DatasetPreparationPhase.idle => 'Ready to start preparation',
          DatasetPreparationPhase.preparing => 'Checking the plan and storage',
          DatasetPreparationPhase.downloading => 'Downloading',
          DatasetPreparationPhase.assembling => 'Assembling files',
          DatasetPreparationPhase.validating =>
            'Verifying integrity and compatibility',
          DatasetPreparationPhase.activating =>
            'Committing the revision pointer atomically',
          DatasetPreparationPhase.active =>
            'Revision atomic transaction completed',
          DatasetPreparationPhase.cancelled => 'Preparation cancelled',
          DatasetPreparationPhase.failed => 'Preparation failed',
        },
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.copy(
                  'تجهيز Dataset المعتمد',
                  'Approved Dataset preparation',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.binding.revision, textDirection: TextDirection.ltr),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(phase)),
              if (c.busy) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: c.totalBytes > 0
                      ? (c.downloadedBytes / c.totalBytes).clamp(0, 1)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  '${c.downloadedBytes} / ${c.totalBytes} bytes',
                  textDirection: TextDirection.ltr,
                ),
                TextButton(
                  onPressed: () => unawaited(c.cancel()),
                  child: Text(context.tr('إلغاء')),
                ),
              ],
              if (c.failure case final error?)
                SirajProblemCard(
                  problem: SirajProblem.from(error, area: ProblemArea.dataset),
                  onRetry: !c.busy && _consented
                      ? () => unawaited(_start())
                      : null,
                ),
              if (!c.busy && c.phase != DatasetPreparationPhase.active)
                FilledButton(
                  onPressed: () => unawaited(_start()),
                  child: Text(
                    context.copy(
                      _consented
                          ? 'استئناف أو إعادة المحاولة'
                          : 'بدء تجهيز Dataset',
                      _consented ? 'Resume or retry' : 'Prepare Dataset',
                    ),
                  ),
                ),
              Text(
                context.copy(
                  'إكمال التنزيل وحده لا يثبت RAG_READY أو نجاح اختبارات Android التعليمية.',
                  'Completing a download alone does not prove RAG_READY or Android educational acceptance.',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
