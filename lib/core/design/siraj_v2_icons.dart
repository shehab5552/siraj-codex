import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Local, exact SVG glyphs from the approved V2 HTML; no network or icon font.
class SirajV2Icon extends StatelessWidget {
  const SirajV2Icon(this.name, {super.key, this.size = 20, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/v2/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}

/// Compatibility seam for existing design components. Unknown Material icons
/// keep their native glyph; all reference counterparts use the supplied paths.
class SirajReferenceIcon extends StatelessWidget {
  const SirajReferenceIcon(this.icon, {super.key, this.size = 20, this.color});
  final IconData icon;
  final double size;
  final Color? color;
  static String? nameFor(IconData icon) => switch (icon) {
    Icons.home || Icons.home_outlined => 'home',
    Icons.chat_bubble ||
    Icons.chat_bubble_outline ||
    Icons.add_comment_outlined ||
    Icons.forum_outlined => 'message',
    Icons.menu_book ||
    Icons.menu_book_outlined ||
    Icons.book_outlined => 'book',
    Icons.quiz || Icons.quiz_outlined || Icons.school_outlined => 'graduation',
    Icons.settings || Icons.settings_outlined => 'settings',
    Icons.chevron_left ||
    Icons.chevron_right ||
    Icons.arrow_forward_ios => 'chevron',
    Icons.auto_awesome_outlined => 'sparkles',
    Icons.person_outline => 'user',
    Icons.download_outlined || Icons.file_download_outlined => 'download',
    Icons.history => 'history',
    Icons.picture_as_pdf_outlined || Icons.description_outlined => 'file',
    Icons.inventory_2_outlined || Icons.memory_outlined => 'cpu',
    Icons.shield_outlined => 'shield',
    Icons.info_outline => 'info',
    Icons.error_outline || Icons.warning_amber_outlined => 'alert',
    Icons.refresh => 'refresh',
    Icons.send || Icons.send_outlined => 'send',
    Icons.delete_outline => 'trash',
    Icons.search => 'search',
    _ => null,
  };
  @override
  Widget build(BuildContext context) {
    final name = nameFor(icon);
    return name == null
        ? Icon(icon, size: size, color: color)
        : SirajV2Icon(name, size: size, color: color);
  }
}
