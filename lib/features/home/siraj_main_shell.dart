import 'package:flutter/material.dart';
import '../../core/design/siraj_components.dart';
import '../../core/design/siraj_design.dart';
import 'home_page.dart';

enum SirajMainTab { home, assistant, library, quiz }

class SirajMainShell extends StatefulWidget {
  const SirajMainShell({
    super.key, this.onOpenChat, this.onOpenResources, this.onOpenHistory, this.onOpenQuiz,
  });
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
    if (selected == SirajMainTab.quiz && widget.onOpenQuiz != null) {
      widget.onOpenQuiz!();
      return;
    }
    if (selected == SirajMainTab.assistant && widget.onOpenChat != null) {
      widget.onOpenChat!();
      return;
    }
    setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selected.index;
    final pages = <Widget>[
      HomePage(onOpenChat: widget.onOpenChat, onOpenResources: widget.onOpenResources, onOpenHistory: widget.onOpenHistory, onOpenQuiz: widget.onOpenQuiz),
      const SirajStatusView(
        title: 'المساعد المحلي',
        message: 'تحتاج المحادثة إلى جلسة حساب موثقة. لا توجد إجابات مولدة تجريبيًا.',
        icon: Icons.chat_bubble_outline,
      ),
      const SirajStatusView(
        title: 'المكتبة',
        message: 'قائمة الكتب وتنزيل ملفات PDF المعتمدة غير موصولين في هذا الفرع بعد.',
        icon: Icons.menu_book_outlined,
      ),
      const SirajStatusView(
        title: 'اختبر معلوماتك',
        message: 'يتطلب توليد الأسئلة النموذج المحلي وبيانات RAG المتوافقة والمراجعة. لا توجد أسئلة جاهزة.',
        icon: Icons.quiz_outlined,
      ),
    ];
    final width = MediaQuery.sizeOf(context).width;
    final navigation = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
      const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'المساعد'),
      const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'المكتبة'),
      const NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: 'الاختبارات'),
    ];
    // Keep exactly one selected destination, even for unavailable features.
    final body = KeyedSubtree(key: ValueKey(_selected), child: pages[selectedIndex]);
    if (width >= SirajBreakpoints.expanded) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: _select,
            labelType: NavigationRailLabelType.all,
            destinations: navigation.map((tab) => NavigationRailDestination(
              icon: tab.icon, selectedIcon: tab.selectedIcon, label: Text(tab.label),
            )).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
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
