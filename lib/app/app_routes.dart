import 'package:flutter/material.dart';

import '../features/chat/chat_page.dart';

abstract final class AppRoutes {
  static const String chat = '/chat';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chat:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => const ChatPage(),
        );
      default:
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => const Scaffold(
            body: Center(child: Text('الصفحة المطلوبة غير متاحة.')),
          ),
        );
    }
  }
}
