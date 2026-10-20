import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/home/home_page.dart';

/// B-02 bootstrap. The real session/auth gate is implemented in B-04.
/// Never expose the development preview in profile/release builds.
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      return const HomePage();
    }

    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'سراج قيد التجهيز. الدخول غير متاح حتى اكتمال '
              'الحساب المحلي والجلسة الآمنة (B-04).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
