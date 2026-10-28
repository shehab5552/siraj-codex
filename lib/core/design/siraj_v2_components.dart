import 'package:flutter/material.dart';
import 'siraj_design.dart';

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
              ? const Color(0xFF213A57)
              : SirajPalette.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          'س',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            color: Colors.white,
            fontSize: size * .64,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
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
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      ...actions,
      if (showBack && Navigator.of(context).canPop()) const BackButton(),
      const SizedBox(width: 7),
    ],
  );
}

class SirajIconTile extends StatelessWidget {
  const SirajIconTile({
    super.key,
    required this.icon,
    this.teal = false,
    this.size = 42,
  });
  final IconData icon;
  final bool teal;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: teal ? c.secondary.withValues(alpha: .1) : c.primaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 20, color: teal ? c.secondary : c.primary),
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

class SirajStatusPill extends StatelessWidget {
  const SirajStatusPill({super.key, required this.text, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: warning
          ? (Theme.of(context).extension<SirajSemanticColors>()?.warning ??
                    Theme.of(context).colorScheme.error)
                .withValues(alpha: .12)
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(50),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: warning
            ? (Theme.of(context).extension<SirajSemanticColors>()?.warning ??
                  Theme.of(context).colorScheme.error)
            : Theme.of(context).colorScheme.primary,
      ),
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
        ? (Theme.of(context).extension<SirajSemanticColors>()?.warning ??
              c.error)
        : c.primary;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
