import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/auth_models.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/chat_turn_coordinator.dart';
import '../features/chat/conversation_draft_controller.dart';
import '../integrations/ai/tutor_port.dart';

/// Authenticated chat navigation must carry a verified session plus a
/// repository-backed draft controller. The controller checks SQLite again
/// before committing the first message.
class AuthenticatedChatRoute {
  const AuthenticatedChatRoute({
    required this.session,
    required this.draftController,
    this.tutor = const UnavailableTutorPort(),
    this.sources = const UnavailableSourceResolver(),
  });

  final AuthSession session;
  final ConversationDraftController draftController;
  final TutorPort tutor;
  final SourceResolverPort sources;
}

abstract final class AppRoutes {
  static const String chat = '/chat';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chat:
        final arguments = settings.arguments;
        if (arguments is AuthenticatedChatRoute) {
          final coordinator = ChatTurnCoordinator.fromDraft(
            arguments.draftController,
            arguments.session,
            tutor: arguments.tutor,
            sources: arguments.sources,
          );
          return MaterialPageRoute<dynamic>(
            settings: settings,
            builder: (_) => ChatPage(coordinator: coordinator),
          );
        }
        // Preserve the B-02 debug preview, but never give release/profile
        // an unguarded path into the chat page.
        if (kDebugMode) {
          return MaterialPageRoute<dynamic>(
            settings: settings,
            builder: (_) => const ChatPage(),
          );
        }
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => const Scaffold(
            body: Center(child: Text('يلزم تسجيل دخول صالح لفتح المحادثة.')),
          ),
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
