import '../../core/design/siraj_v2_components.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/presentation/siraj_problem.dart';
import '../../app/presentation/siraj_problem_card.dart';
import '../../core/design/siraj_components.dart';
import '../../core/localization/siraj_copy.dart';
import 'library_contracts.dart';
import 'library_controller.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.controller,
    required this.onOpenResources,
  });
  final LibraryController controller;
  final VoidCallback onOpenResources;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    unawaited(c.load());
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  double? _progress(LibraryBook book) {
    final progress = c.progress(book);
    final total = progress?.totalBytes;
    if (progress == null || total == null || total <= 0) return null;
    return (progress.downloadedBytes / total).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: SirajAppBar(
        title: context.tr('المكتبة'),
        subtitle: context.copy(
          'كتب PDF مستقلة ومحلية',
          'Independent, local PDF books',
        ),
        actions: [
          IconButton(
            tooltip: context.tr('حالة الموارد'),
            onPressed: widget.onOpenResources,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: context.copy('تحديث المكتبة', 'Refresh library'),
            onPressed: c.loading ? null : () => unawaited(c.load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.copy(
                    'كتبك ومصادرك الدراسية',
                    'Your books and learning resources',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.copy(
                    'كتب PDF مستقلة عن LLM وRAG. لا يُعرض كتاب كقابل للفتح قبل فحص ملفه بقارئ معتمد.',
                    'PDF books are independent of LLM and RAG. A book is never offered for opening before its file is verified by an approved reader.',
                  ),
                ),
                const SizedBox(height: 16),
                if (c.loading) const LinearProgressIndicator(),
                if (c.failure case final error?)
                  SirajProblemCard(
                    problem: SirajProblem.from(error, area: ProblemArea.pdf),
                    onRetry: () => unawaited(c.load()),
                    onResources: widget.onOpenResources,
                  ),
                if (!c.loading && !c.catalogAvailable)
                  SirajStatusView(
                    icon: Icons.menu_book_outlined,
                    title: context.copy(
                      'فهرس الكتب غير متاح',
                      'Book catalog unavailable',
                    ),
                    message: context.copy(
                      'لم يُوفّر فهرس رسمي معتمد للكتب بعد. لن تُعرض كتب أو صفحات وهمية.',
                      'An approved official book catalog has not been provided. No invented books or pages are shown.',
                    ),
                    actionLabel: context.tr('حالة الموارد'),
                    onAction: widget.onOpenResources,
                  ),
                if (c.catalogAvailable) ...[
                  TextField(
                    key: const Key('library-search'),
                    onChanged: c.setQuery,
                    decoration: InputDecoration(
                      labelText: context.copy('ابحث في الكتب', 'Search books'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(context.copy('الكل', 'All')),
                        selected: c.category == null,
                        onSelected: (_) => c.setCategory(null),
                      ),
                      for (final category in c.categories)
                        ChoiceChip(
                          label: Text(
                            context.copy(
                              category.categoryArabic,
                              category.categoryEnglish,
                            ),
                          ),
                          selected: c.category == category.categoryId,
                          onSelected: (_) => c.setCategory(category.categoryId),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (c.books.isEmpty)
                    SirajStatusView(
                      title: context.copy(
                        'لا توجد كتب مطابقة',
                        'No matching books',
                      ),
                      message: context.copy(
                        'جرّب عبارة بحث أو تصنيفًا آخر. لا تُضاف كتب خارج الفهرس المعتمد.',
                        'Try another search or category. Books outside the approved catalog are not added.',
                      ),
                    ),
                  for (final book in c.books)
                    SirajCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.copy(
                                        book.arabicTitle,
                                        book.englishTitle,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.copy(
                                        book.categoryArabic,
                                        book.categoryEnglish,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.copy(
                              switch (c.state(book)) {
                                BookFileState.missing => 'الملف غير محمل',
                                BookFileState.unverified =>
                                  'يتطلب التحقق من الملف',
                                BookFileState.readerRequired =>
                                  'القارئ المحلي المعتمد غير متاح',
                                BookFileState.readable =>
                                  'فُحص الملف ويمكن فتحه محليًا',
                                BookFileState.invalid =>
                                  'تعذر التحقق من سلامة الملف',
                              },
                              switch (c.state(book)) {
                                BookFileState.missing => 'File not downloaded',
                                BookFileState.unverified =>
                                  'File verification required',
                                BookFileState.readerRequired =>
                                  'The approved local reader is unavailable',
                                BookFileState.readable =>
                                  'File verified and available locally',
                                BookFileState.invalid =>
                                  'File integrity could not be verified',
                              },
                            ),
                          ),
                          if (c.busy(book)) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: _progress(book)),
                            TextButton(
                              onPressed: () => unawaited(c.cancel(book)),
                              child: Text(context.tr('إلغاء')),
                            ),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (c.canDownload(book))
                                OutlinedButton.icon(
                                  key: Key('library-download-${book.id}'),
                                  onPressed: () => unawaited(c.download(book)),
                                  icon: const Icon(Icons.download_outlined),
                                  label: Text(
                                    context.copy(
                                      'تنزيل الكتاب',
                                      'Download book',
                                    ),
                                  ),
                                ),
                              if (c.canOpen(book))
                                FilledButton.icon(
                                  key: Key('library-open-${book.id}'),
                                  onPressed: () => unawaited(c.open(book)),
                                  icon: const Icon(Icons.menu_book_outlined),
                                  label: Text(
                                    context.copy('فتح محليًا', 'Open locally'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
