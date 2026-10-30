import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/core/design/siraj_navigation.dart';

void main() {
  testWidgets(
    'reference navigation selects the measured 90.75x57 tile with accessible targets',
    (t) async {
      t.view.physicalSize = const Size(380, 737);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var selected = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: SirajTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => Directionality(
              textDirection: TextDirection.rtl,
              child: SirajAdaptiveNavigation(
                index: selected,
                onSelect: (i) => setState(() => selected = i),
                body: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      final first = find.byKey(const Key('v2-nav-tile-0'));
      expect(first, findsOneWidget);
      expect(t.getSize(first), const Size(90.75, 57));
      final box = t.widget<DecoratedBox>(first);
      expect(
        (box.decoration as BoxDecoration).color,
        SirajTheme.light().colorScheme.primaryContainer,
      );
      await t.tap(find.text('المكتبة الدراسية'));
      await t.pumpAndSettle();
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(
        (t
                    .widget<DecoratedBox>(
                      find.byKey(const Key('v2-nav-tile-0')),
                    )
                    .decoration
                as BoxDecoration)
            .color,
        Colors.transparent,
      );
      final semantics = t.ensureSemantics();
      try {
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );
}
