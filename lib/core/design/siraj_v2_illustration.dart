import 'package:flutter/material.dart';
import 'siraj_v2_icons.dart';

/// Measured V2 halo and bookicon, shared by onboarding and empty chat.
class SirajV2Illustration extends StatelessWidget {
  const SirajV2Illustration({
    super.key,
    required this.icon,
    this.compact = false,
  });
  final String icon;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final halo = Container(
      key: const Key('v2-illustration-halo'),
      width: compact ? 116 : 202,
      height: compact ? 116 : 202,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-.2, -.26),
          radius: .825,
          stops: [0, .7, .72],
          colors: [Color(0xFFE3F6F3), Color(0xFFDCEAFD), Color(0x00DCEAFD)],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        key: const Key('v2-illustration-bookicon'),
        width: compact ? 73 : 102,
        height: compact ? 73 : 103,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1B3957) : const Color(0xFF102B46),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33102B46),
              blurRadius: 38,
              offset: Offset(0, 14),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: SirajV2Icon(icon, size: 50, color: Colors.white),
      ),
    );
    if (compact) return halo;
    Widget floating(String icon) => Container(
      width: 42,
      height: 52,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17102B46),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: SirajV2Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    return SizedBox(
      key: const Key('v2-onboarding-illustration'),
      height: 227,
      child: Stack(
        alignment: Alignment.center,
        children: [
          halo,
          Positioned(top: 31, left: 45, child: floating('sparkles')),
          Positioned(bottom: 24, right: 43, child: floating('book')),
        ],
      ),
    );
  }
}
