import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
import 'app_routes.dart';

class SirajApp extends StatelessWidget {
  const SirajApp({super.key, this.debugPreview = false});

  /// Only explicitly used in debug widget tests; never in release/profile.
  final bool debugPreview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سراج',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF254A65)),
        useMaterial3: true,
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppBootstrap(debugPreview: debugPreview && kDebugMode),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
