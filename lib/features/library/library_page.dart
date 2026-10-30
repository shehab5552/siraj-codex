import '../../core/design/siraj_v2_components.dart';
import '../../core/design/siraj_v2_icons.dart';
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
        title: context.copy('مكتبة الكتب', 'Book library'),
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
              padding: const EdgeInsets.fromLTRB(15, 17, 15, 18),
              children: [
                Text(
                  context.copy(
                    'كتبك ومصادرك الدراسية',
                    'Your books and learning resources',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  context.copy(
                    'نزّل كل كتاب على حدة، وافتحه محليًا بعد التحقق. ملفات PDF مستقلة عن LLM وRAG.',
                    'PDF books are independent of LLM and RAG. A book is never offered for opening before its file is verified by an approved reader.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
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
                  for (final book in c.books) _bookCard(context, book),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _bookCard(BuildContext context, LibraryBook book) {
    final state = c.state(book);
    final readable = state == BookFileState.readable;
    final invalid = state == BookFileState.invalid;
    final label = context.copy(
      switch (state) {
        BookFileState.missing => 'غير منزّل',
        BookFileState.unverified => 'بانتظار التحقق',
        BookFileState.readerRequired => 'القارئ غير متاح',
        BookFileState.readable => 'متاح محليًا',
        BookFileState.invalid => 'فشل التحقق',
      },
      switch (state) {
        BookFileState.missing => 'Not downloaded',
        BookFileState.unverified => 'Verification required',
        BookFileState.readerRequired => 'Reader unavailable',
        BookFileState.readable => 'Available locally',
        BookFileState.invalid => 'Verification failed',
      },
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.copy(book.arabicTitle, book.englishTitle),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.copy(book.categoryArabic, book.categoryEnglish),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SirajStatusPill(
              text: label,
              tone: readable
                  ? SirajPillTone.good
                  : invalid
                  ? SirajPillTone.error
                  : SirajPillTone.gray,
            ),
          ),
        ),
        if (c.busy(book)) ...[
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
                icon: const SirajV2Icon('download', size: 16),
                label: Text(context.copy('تنزيل الكتاب', 'Download book')),
              ),
            if (c.canOpen(book))
              FilledButton.icon(
                key: Key('library-open-${book.id}'),
                onPressed: () => unawaited(c.open(book)),
                icon: const SirajV2Icon('book', size: 16),
                label: Text(context.copy('فتح محليًا', 'Open locally')),
              ),
          ],
        ),
      ],
    );
    final cover = Container(
      width: 66,
      height: 93,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF234D80), Color(0xFF102B46)],
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(color: Color(0xFFB9CDE4), offset: Offset(4, 5)),
        ],
      ),
      alignment: Alignment.center,
      child: const SirajV2Icon('book', size: 25, color: Colors.white),
    );
    return SirajCard(
      child: MediaQuery.textScalerOf(context).scale(12) > 18
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [cover, const SizedBox(height: 13), details],
            )
          : Row(
              children: [
                cover,
                const SizedBox(width: 13),
                Expanded(child: details),
              ],
            ),
    );
  }
}
