import 'package:flutter/material.dart';
import '../../core/design/siraj_components.dart';
import '../../core/localization/siraj_copy.dart';

/// No official PDF catalog has been supplied. Do not derive books/subjects from
/// the visual prototype or mistake arbitrary registered files for approved books.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.onOpenResources});
  final VoidCallback onOpenResources;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('المكتبة'))),
    body: SafeArea(
      child: SingleChildScrollView(
        child: SirajStatusView(
          icon: Icons.menu_book_outlined,
          title: context.copy(
            'فهرس الكتب غير متاح',
            'Book catalog unavailable',
          ),
          message: context.copy(
            'لم يُوفّر فهرس رسمي معتمد للكتب بعد. لن تُعرض كتب أو صفحات وهمية. ملفات PDF مستقلة عن النموذج وبيانات RAG.',
            'An approved official book catalog has not been provided. No invented books or pages are shown. PDF files are independent of the model and RAG data.',
          ),
          actionLabel: context.tr('حالة الموارد'),
          onAction: onOpenResources,
        ),
      ),
    ),
  );
}
