import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/conversation_repository.dart';
import 'package:siraj/data/user_repository.dart';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/auth_service.dart';
import 'package:siraj/features/auth/password_hasher.dart';
import 'package:siraj/features/auth/session_guard.dart';
import 'package:siraj/features/chat/conversation_draft_controller.dart';
import 'support/auth_test_marker.dart';

class GuardThenLogout extends SessionGuard {
  GuardThenLogout(super.users, this.logout);
  final Future<void> Function() logout;
  @override
  Future<bool> isCurrent(AuthSession session) async {
    final valid = await super.isCurrent(session);
    await logout();
    return valid;
  }
}

void main() {
  test(
    'Logout between early guard and first USER transaction blocks all writes',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final users = UserRepository(db);
      final auth = AuthService(
        users: users,
        passwordHasher: PasswordHasher(iterations: 10),
        markerStore: ControlledMarker(),
      );
      try {
        final session = await auth.createAccount(
          username: 'test-only',
          password: 'synthetic',
          confirmation: 'synthetic',
        );
        final chats = ConversationRepository(db);
        final draft = ConversationDraftController(
          conversations: chats,
          guard: GuardThenLogout(users, auth.logout),
        );
        await expectLater(
          draft.commitFirstQuestion(
            session: session,
            question: 'late question',
          ),
          throwsA(anything),
        );
        expect(
          await chats.listConversations(
            userId: session.userId,
            accountEpoch: session.accountEpoch,
          ),
          isEmpty,
        );
        expect(
          (await users.currentAccount())!.read<Uint8List?>(
            'active_session_nonce_hash',
          ),
          isNull,
        );
      } finally {
        await db.close();
      }
    },
  );
}
