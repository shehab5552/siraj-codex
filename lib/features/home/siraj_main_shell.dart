import '../../core/design/siraj_navigation.dart';
import 'package:flutter/material.dart';
import '../../core/design/siraj_components.dart';
import 'home_page.dart';

enum SirajMainTab { home, assistant, library, quiz }

class SirajMainShell extends StatefulWidget {
  const SirajMainShell({
    super.key,
    this.onOpenChat,
    this.onOpenResources,
    this.onOpenHistory,
    this.onOpenQuiz,
    this.assistantPage,
    this.libraryPage,
    this.quizPage,
    this.onOpenSettings,
    this.latestConversationTitle,
    this.onOpenLatest,
  });
  final Widget? assistantPage, libraryPage, quizPage;
  final VoidCallback? onOpenSettings, onOpenLatest;
  final String? latestConversationTitle;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenResources;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenQuiz;
  @override
  State<SirajMainShell> createState() => _SirajMainShellState();
}

class _SirajMainShellState extends State<SirajMainShell> {
  SirajMainTab _selected = SirajMainTab.home;

  void _select(int index) {
    final scope = SirajTabScope.maybeOf(context);
    if (scope != null) {
      scope.select(index);
      return;
    }
    final selected = SirajMainTab.values[index];
    setState(() => _selected = selected);
    if (selected == SirajMainTab.quiz &&
        widget.quizPage == null &&
        widget.onOpenQuiz != null) {
      widget.onOpenQuiz!();
      return;
    }
    if (selected == SirajMainTab.assistant &&
        widget.assistantPage == null &&
        widget.onOpenChat != null) {
      widget.onOpenChat!();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = SirajTabScope.maybeOf(context);
    final selectedIndex = scope?.index ?? _selected.index;
    final pages = <Widget>[
      HomePage(
        onOpenChat: widget.onOpenChat,
        onOpenResources: widget.onOpenResources,
        onOpenHistory: widget.onOpenHistory,
        onOpenQuiz: widget.quizPage == null
            ? widget.onOpenQuiz
            : () => _select(3),
        onOpenLibrary: () => _select(2),
        onOpenSettings: widget.onOpenSettings,
        latestConversationTitle: widget.latestConversationTitle,
        onOpenLatest: widget.onOpenLatest,
      ),
      widget.assistantPage ??
          const SirajStatusView(
            title: 'المساعد المحلي',
            message:
                'تحتاج المحادثة إلى جلسة حساب موثقة. لا توجد إجابات مولدة تجريبيًا.',
            icon: Icons.chat_bubble_outline,
          ),
      widget.libraryPage ??
          const SirajStatusView(
            title: 'المكتبة',
            message:
                'قائمة الكتب وتنزيل ملفات PDF المعتمدة غير موصولين في هذا الفرع بعد.',
            icon: Icons.menu_book_outlined,
          ),
      widget.quizPage ??
          const SirajStatusView(
            title: 'اختبر معلوماتك',
            message:
                'يتطلب توليد الأسئلة النموذج المحلي وبيانات RAG المتوافقة والمراجعة. لا توجد أسئلة جاهزة.',
            icon: Icons.quiz_outlined,
          ),
    ];
    final body = IndexedStack(index: selectedIndex, children: pages);
    if (scope != null) return body;
    return SirajAdaptiveNavigation(
      index: selectedIndex,
      onSelect: _select,
      body: body,
    );
  }
}
