import 'package:flutter/material.dart';
import '../../core/design/siraj_components.dart';
import '../../core/design/siraj_design.dart';
import '../../core/localization/siraj_copy.dart';
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
    final selectedIndex = _selected.index;
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
    final width = MediaQuery.sizeOf(context).width;
    final navigation = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: context.tr('الرئيسية'),
      ),
      NavigationDestination(
        icon: Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble),
        label: context.tr('المساعد'),
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: context.tr('المكتبة'),
      ),
      NavigationDestination(
        icon: Icon(Icons.quiz_outlined),
        selectedIcon: Icon(Icons.quiz),
        label: context.tr('الاختبارات'),
      ),
    ];
    // Keep exactly one selected destination, even for unavailable features.
    final body = IndexedStack(index: selectedIndex, children: pages);
    if (width >= SirajBreakpoints.expanded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: navigation
                  .map(
                    (tab) => NavigationRailDestination(
                      icon: tab.icon,
                      selectedIcon: tab.selectedIcon,
                      label: Text(tab.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        key: const Key('siraj-bottom-navigation'),
        selectedIndex: selectedIndex,
        onDestinationSelected: _select,
        destinations: navigation,
      ),
    );
  }
}
