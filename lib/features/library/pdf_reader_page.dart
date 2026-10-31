import 'package:flutter/material.dart';
import '../../app/presentation/siraj_problem.dart';
import '../../app/presentation/siraj_problem_card.dart';
import '../../core/design/siraj_v2_components.dart';
import '../../core/localization/siraj_copy.dart';
import 'pdf_reader_controller.dart';

/// Presentation only. The library operation owns native cleanup and the file
/// pin, even after this route disappears on logout or deletion.
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.controller,
    required this.arabicTitle,
    required this.englishTitle,
  });
  final PdfReaderController controller;
  final String arabicTitle, englishTitle;
  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final _transform = TransformationController();
  PdfReaderController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.showPage(0);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _page(int target) {
    _transform.value = Matrix4.identity();
    c.showPage(target);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: SirajAppBar(
        title: context.copy(widget.arabicTitle, widget.englishTitle),
        subtitle: context.copy('قارئ PDF محلي', 'Local PDF reader'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Center(
                  child: c.closed
                      ? Text(context.copy('أُغلق المستند', 'Document closed'))
                      : c.failure != null
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(15),
                          child: SirajProblemCard(
                            problem: SirajProblem.from(
                              c.failure!,
                              area: ProblemArea.pdf,
                            ),
                            onRetry: c.retry,
                          ),
                        )
                      : c.image == null
                      ? const CircularProgressIndicator()
                      : InteractiveViewer(
                          key: ValueKey('pdf-page-${c.page}'),
                          transformationController: _transform,
                          minScale: 1,
                          maxScale: 4,
                          child: Image.memory(
                            c.image!.png,
                            fit: BoxFit.contain,
                            gaplessPlayback: false,
                            semanticLabel: context.copy(
                              'الصفحة ${c.page + 1}',
                              'Page ${c.page + 1}',
                            ),
                            errorBuilder: (_, _, _) => Text(
                              context.copy(
                                'تعذر عرض الصفحة',
                                'Could not display this page',
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  IconButton(
                    key: const Key('pdf-previous'),
                    tooltip: context.tr('السابق'),
                    onPressed: c.closed || c.page == 0
                        ? null
                        : () => _page(c.page - 1),
                    icon: const Icon(Icons.navigate_before),
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.copy(
                        'صفحة ${c.page + 1} من ${c.pageCount}',
                        'Page ${c.page + 1} of ${c.pageCount}',
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('pdf-next'),
                    tooltip: context.copy('التالي', 'Next'),
                    onPressed: c.closed || c.page >= c.pageCount - 1
                        ? null
                        : () => _page(c.page + 1),
                    icon: const Icon(Icons.navigate_next),
                  ),
                  IconButton(
                    tooltip: context.copy('إعادة التكبير', 'Reset zoom'),
                    onPressed: () => _transform.value = Matrix4.identity(),
                    icon: const Icon(Icons.fit_screen),
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
