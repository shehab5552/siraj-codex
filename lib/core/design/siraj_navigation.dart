import 'package:flutter/material.dart';
import '../localization/siraj_copy.dart';
import 'siraj_design.dart';

/// Presentation state only; the application host authorizes actual navigation.
class SirajTabScope extends InheritedWidget {
  const SirajTabScope({
    super.key,
    required this.index,
    required this.select,
    required this.setContext,
    required super.child,
  });
  final int index;
  final ValueChanged<int> select, setContext;
  static SirajTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SirajTabScope>();
  @override
  bool updateShouldNotify(SirajTabScope oldWidget) => index != oldWidget.index;
}

class SirajAdaptiveNavigation extends StatelessWidget {
  const SirajAdaptiveNavigation({
    super.key,
    required this.index,
    required this.onSelect,
    required this.body,
    this.suspended = false,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;
  final bool suspended;
  @override
  Widget build(BuildContext context) {
    final tabs = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: context.tr('الرئيسية'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: context.tr('المساعد'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.menu_book_outlined),
        selectedIcon: const Icon(Icons.menu_book),
        label: context.tr('المكتبة'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.quiz_outlined),
        selectedIcon: const Icon(Icons.quiz),
        label: context.tr('الاختبارات'),
      ),
    ];
    Widget guarded(Widget child) => Stack(
      children: [
        IgnorePointer(
          ignoring: suspended,
          child: ExcludeSemantics(excluding: suspended, child: child),
        ),
        if (suspended)
          const Positioned.fill(child: ColoredBox(color: Colors.black54)),
      ],
    );
    if (MediaQuery.sizeOf(context).width >= SirajBreakpoints.expanded) {
      return Scaffold(
        body: Row(
          children: [
            guarded(
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                destinations: tabs
                    .map(
                      (t) => NavigationRailDestination(
                        icon: t.icon,
                        selectedIcon: t.selectedIcon,
                        label: Text(t.label),
                      ),
                    )
                    .toList(),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: guarded(
        NavigationBar(
          key: const Key('siraj-bottom-navigation'),
          selectedIndex: index,
          onDestinationSelected: onSelect,
          destinations: [
            for (var i = 0; i < tabs.length; i++)
              _ReferenceDestination(
                icon: tabs[i].icon,
                label: tabs[i].label,
                selected: index == i,
                onTap: () => onSelect(i),
                tileIndex: i,
              ),
          ],
        ),
      ),
    );
  }
}

/// Keeps NavigationBar's focus/layout contract while painting V2's full-cell
/// selection instead of Material3's small pill. Navigation authorization stays
/// in the host callback; this component owns no route or session behavior.
class _ReferenceDestination extends NavigationDestination {
  const _ReferenceDestination({
    required super.icon,
    required super.label,
    required this.selected,
    required this.onTap,
    required this.tileIndex,
  });
  final bool selected;
  final VoidCallback onTap;
  final int tileIndex;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        onTap: onTap,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: DecoratedBox(
            key: Key('v2-nav-tile-$tileIndex'),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme(
                      data: IconThemeData(color: color, size: 20),
                      child: icon,
                    ),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
