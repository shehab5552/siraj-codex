import 'package:flutter/material.dart';
import 'siraj_design.dart';
import 'siraj_v2_icons.dart';

/// V2's reference monogram. Replaced only by a traceable, supplied brand asset;
/// this is not represented as the extracted official lantern/book artwork.
class SirajBrandMark extends StatelessWidget {
  const SirajBrandMark({super.key, this.size = 37});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'SIRAJ',
    image: true,
    child: ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B3957)
              : SirajPalette.navy,
          borderRadius: BorderRadius.circular(size == 64 ? 18 : 12),
        ),
        alignment: Alignment.center,
        child: Image.asset(
          'assets/branding/app_mark.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}

class SirajAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SirajAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  @override
  Size get preferredSize => const Size.fromHeight(68);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: 15,
    shape: Border(
      bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    title: Row(
      children: [
        const SirajBrandMark(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  fontVariations: const [FontVariation('wght', 900)],
                ),
              ),
              if (subtitle != null &&
                  MediaQuery.textScalerOf(context).scale(10) <= 14)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      for (final action in actions)
        if (action is IconButton)
          SirajHeaderAction(
            key: action.key,
            icon: action.icon,
            tooltip: action.tooltip,
            onPressed: action.onPressed,
          )
        else
          action,
      if (showBack && Navigator.of(context).canPop())
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: _headerFrame(
                  context,
                  const SirajV2Icon('chevron', size: 18),
                ),
              ),
              const BackButton(color: Colors.transparent),
            ],
          ),
        ),
      const SizedBox(width: 11),
    ],
  );
}

class SirajIconTile extends StatelessWidget {
  const SirajIconTile({
    super.key,
    required this.icon,
    this.teal = false,
    this.size = 42,
    this.height,
  });
  final IconData icon;
  final bool teal;
  final double size;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: height ?? size,
      decoration: BoxDecoration(
        color: teal ? c.secondary.withValues(alpha: .1) : c.primaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: SirajReferenceIcon(
          icon,
          size: 20,
          color: teal ? c.secondary : c.primary,
        ),
      ),
    );
  }
}

class SirajSectionHeading extends StatelessWidget {
  const SirajSectionHeading({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.teal = false,
  });
  final String title, description;
  final IconData icon;
  final bool teal;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        SirajIconTile(icon: icon, teal: teal, size: 50),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

enum SirajPillTone { normal, good, gray, error }

class SirajStatusPill extends StatelessWidget {
  const SirajStatusPill({
    super.key,
    required this.text,
    this.warning = false,
    this.tone = SirajPillTone.normal,
  });
  final String text;
  final bool warning;
  final SirajPillTone tone;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = Theme.of(context).colorScheme;
    final (background, foreground) = warning
        ? (
            dark ? const Color(0xFF53391C) : const Color(0xFFFFF4E3),
            dark ? const Color(0xFFFFD391) : const Color(0xFF9B6813),
          )
        : switch (tone) {
            SirajPillTone.good => (
              dark ? const Color(0xFF163B3A) : const Color(0xFFE9F9F5),
              c.secondary,
            ),
            SirajPillTone.gray => (
              Theme.of(context).scaffoldBackgroundColor,
              c.onSurfaceVariant,
            ),
            SirajPillTone.error => (
              dark ? const Color(0xFF4D2D35) : const Color(0xFFFFF0F1),
              dark ? const Color(0xFFFFB6C2) : const Color(0xFFC03341),
            ),
            _ => (c.primaryContainer, c.primary),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground, height: 2.1),
      ),
    );
  }
}

Widget _headerFrame(BuildContext context, Widget icon) => Container(
  width: 40,
  height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    borderRadius: BorderRadius.circular(12),
  ),
  child: icon,
);

class SirajHeaderAction extends StatelessWidget {
  const SirajHeaderAction({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
  });
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: _headerFrame(
      context,
      icon is Icon ? SirajReferenceIcon((icon as Icon).icon!, size: 18) : icon,
    ),
  );
}

class SirajReferenceNotice extends StatelessWidget {
  const SirajReferenceNotice({
    super.key,
    required this.text,
    this.warning = false,
    this.icon = Icons.info_outline,
  });
  final String text;
  final bool warning;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = warning
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFCA77)
              : const Color(0xFF926111))
        : c.primary;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: warning
            ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF44341C)
                  : const Color(0xFFFFF8E9))
            : c.primaryContainer,
        border: Border.all(
          color: warning
              ? (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF685632)
                    : const Color(0xFFF8E5BA))
              : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SirajReferenceIcon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 10,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SirajLabeledField extends StatelessWidget {
  const SirajLabeledField({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          height: 2.1,
          fontWeight: FontWeight.w800,
          fontVariations: [FontVariation('wght', 800)],
        ),
      ),
      const SizedBox(height: 7),
      child,
    ],
  );
}
