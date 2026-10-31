import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_components.dart';
import '../../core/localization/siraj_copy.dart';
import 'package:flutter/material.dart';

import 'resource_status.dart';
import 'resource_status_reader.dart';
import '../../app/resource_preparation_binding.dart';
import 'dataset_preparation_card.dart';

/// B-07 Step 1: status visibility only. No download, install or activation.
///
/// Integrate into the authenticated app navigation after verifying the route
/// contract. This page does not bypass B-06's session gate.
class ResourceStatusPage extends StatefulWidget {
  const ResourceStatusPage({super.key, required this.reader, this.preparation});
  final ResourcePreparationBinding? preparation;

  final ResourceStatusReader reader;

  @override
  State<ResourceStatusPage> createState() => _ResourceStatusPageState();
}

class _ResourceStatusPageState extends State<ResourceStatusPage> {
  late Future<ResourceStatusSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.reader.read();
  }

  @override
  void didUpdateWidget(covariant ResourceStatusPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader) {
      _snapshot = widget.reader.read();
    }
  }

  void _refresh() {
    setState(() => _snapshot = widget.reader.read());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SirajAppBar(
        title: context.copy('إدارة الموارد', 'Manage resources'),
        subtitle: context.copy(
          'تنزيل وفحص الموارد المستقلة',
          'Independent resource downloads and checks',
        ),
      ),
      body: FutureBuilder<ResourceStatusSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('تعذر قراءة حالات الموارد المحلية.')),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _refresh,
                    child: Text(context.tr('إعادة المحاولة')),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
            children: [
              SirajReferenceNotice(
                text: context.copy(
                  'هذه حالات مسجلة محليًا وليست شهادة بجاهزية الملفات. لا تُفعّل الموارد إلا بعد فحص السلامة والتوافق.',
                  'These local records do not certify readiness. Integrity and compatibility checks are required before activation.',
                ),
              ),
              const SizedBox(height: 12),
              _section('النموذج المحلي (LLM)', data.llm),
              _section('حزم بيانات RAG', data.ragPacks),
              _section('نموذج Query Embedding المشترك', data.ragEmbedding),
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  context.tr(
                    'نموذج Embedding جزء من تجهيز Dataset، وليس تنزيلًا منفصلًا. '
                    'لا تتحقق RAG_READY من سجلات الموارد وحدها.',
                  ),
                ),
              ),
              _section('كتب PDF', data.pdfBooks),
              if (widget.preparation case final binding?)
                DatasetPreparationCard(binding: binding)
              else
                Card(
                  key: const Key('resource-catalog-unavailable'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
                    child: Text(
                      context.copy(
                        'لم يتوفر فهرس تنزيل معتمد وروابط وهوية موارد وفاحص Runtime متوافق. لن يُعرض تنزيل تجريبي أو حالة جاهزية وهمية.',
                        'An approved download catalog, resource identities, URLs and compatible runtime validator have not been provided. No demo download or false readiness is offered.',
                      ),
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(
                  context.copy('تحديث السجل المحلي', 'Refresh local registry'),
                ),
              ),

              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  context.tr(
                    'كتب PDF مستقلة عن نموذج الذكاء الاصطناعي وبيانات RAG.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<ResourceStatusEntry> entries) {
    final isPdf = title == 'كتب PDF';
    final isLlm = title == 'النموذج المحلي (LLM)';
    return SirajCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SirajIconTile(
                icon: isPdf
                    ? Icons.description_outlined
                    : isLlm
                    ? Icons.memory_outlined
                    : Icons.menu_book_outlined,
                teal: isLlm,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(title),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SirajStatusPill(
                  text: context.copy('غير مجهّز', 'Not prepared'),
                  tone: SirajPillTone.gray,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              context.tr('لا توجد موارد مسجلة في هذا القسم.'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.resourceId,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(context.tr(entry.statusLabel)),
                leading: SirajIconTile(
                  icon: entry.displayState == ResourceDisplayState.failed
                      ? Icons.error_outline
                      : Icons.info_outline,
                ),
              ),
        ],
      ),
    );
  }
}
