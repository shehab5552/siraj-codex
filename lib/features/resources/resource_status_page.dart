import 'package:flutter/material.dart';

import 'resource_status.dart';
import 'resource_status_reader.dart';

/// B-07 Step 1: status visibility only. No download, install or activation.
///
/// Integrate into the authenticated app navigation after verifying the route
/// contract. This page does not bypass B-06's session gate.
class ResourceStatusPage extends StatefulWidget {
  const ResourceStatusPage({super.key, required this.reader});

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
      appBar: AppBar(title: const Text('حالة الموارد')),
      body: FutureBuilder<ResourceStatusSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر قراءة حالات الموارد المحلية.'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'هذه حالات مسجلة محليًا وليست شهادة بجاهزية الملفات. '
                'لا تُفعّل الموارد إلا بعد فحص السلامة والتوافق.',
              ),
              const SizedBox(height: 12),
              _section('النموذج المحلي (LLM)', data.llm),
              _section('حزم بيانات RAG', data.ragPacks),
              _section('نموذج Query Embedding المشترك', data.ragEmbedding),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'نموذج Embedding جزء من تجهيز Dataset، وليس تنزيلًا منفصلًا. '
                  'لا تتحقق RAG_READY من سجلات الموارد وحدها.',
                ),
              ),
              _section('كتب PDF', data.pdfBooks),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'كتب PDF مستقلة عن نموذج الذكاء الاصطناعي وبيانات RAG.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<ResourceStatusEntry> entries) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              const Text('لا توجد موارد مسجلة في هذا القسم.')
            else
              for (final entry in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.resourceId),
                  subtitle: Text(entry.statusLabel),
                  leading: Icon(
                    entry.displayState == ResourceDisplayState.failed
                        ? Icons.error_outline
                        : Icons.info_outline,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
