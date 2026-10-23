import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/design/siraj_design.dart';
import 'app_bootstrap.dart';
import 'app_routes.dart';

class SirajApp extends StatelessWidget {
  const SirajApp({super.key, this.debugPreview = false});
  final bool debugPreview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سراج',
      debugShowCheckedModeBanner: false,
      theme: SirajTheme.light(),
      darkTheme: SirajTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppBootstrap(debugPreview: debugPreview && kDebugMode),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
