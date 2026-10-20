import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
import 'app_routes.dart';

class SirajApp extends StatelessWidget {
  const SirajApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سراج',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF254A65),
        ),
        useMaterial3: true,
      ),
      // RTL direction for the B-02 UI. Full localization comes separately.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppBootstrap(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
