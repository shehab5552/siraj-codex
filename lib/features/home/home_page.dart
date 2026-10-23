import 'package:flutter/material.dart';
import '../../app/app_routes.dart';
import '../../core/design/siraj_components.dart';
import '../../core/design/siraj_design.dart';

/// No session means an explicitly limited debug preview only.
class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onOpenChat, this.onOpenResources});
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenResources;

  @override
  Widget build(BuildContext context) {
    final authenticated = onOpenChat != null;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('سراج'),
        actions: [
          IconButton(
            tooltip: 'حالة الموارد',
            onPressed: onOpenResources,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: EdgeInsets.all(width < SirajBreakpoints.compact ? 16 : 24),
              children: [
                Text('مرحبًا بك في سراج', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary,
                )),
                const SizedBox(height: SirajSpacing.x3),
                SirajCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.school_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text('تعلّم بثقة، حتى دون اتصال بالإنترنت',
                      style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(authenticated
                      ? 'تم التحقق من الجلسة المحلية. توليد إجابات AI وRAG غير مفعّل حتى اعتماد مواردهما.'
                      : 'معاينة تصميمية في وضع Debug. لا توجد جلسة موثّقة ولا توليد فعلي.',
                      textAlign: TextAlign.center),
                  ],
                )),
                const SizedBox(height: SirajSpacing.x3),
                SirajCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('جاهزية الموارد', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('LLM: غير مثبت الجاهزية'),
                    const Text('RAG: غير مثبت الجاهزية'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('open-resource-status'),
                      onPressed: onOpenResources,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('حالة الموارد'),
                    ),
                  ],
                )),
                const SizedBox(height: SirajSpacing.x3),
                SirajCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('ابدأ الآن', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SirajButton(
                      key: const Key('open-chat'),
                      onPressed: onOpenChat ?? () => Navigator.of(context).pushNamed(AppRoutes.chat),
                      icon: Icons.chat_bubble_outline,
                      label: authenticated ? 'فتح المحادثة' : 'فتح معاينة المحادثة',
                    ),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
