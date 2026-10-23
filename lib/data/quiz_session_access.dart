import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../features/auth/auth_models.dart';
import '../features/auth/session_guard.dart';
import '../features/quiz/quiz_access.dart';
import 'app_database.dart';
import 'conversation_repository.dart';
import 'user_repository.dart';

/// Reuses the existing account/epoch/nonce checks and live SQLite watch. No quiz
/// state is stored, and no new auth policy or write operation is introduced.
class SqliteQuizSessionAccess implements QuizAccessPort {
  const SqliteQuizSessionAccess({
    required this.database,
    required this.session,
  });
  final AppDatabase database;
  final AuthSession session;
  @override
  Future<bool> isCurrent() =>
      SessionGuard(UserRepository(database)).isCurrent(session);
  @override
  Stream<bool> watchValidity() async* {
    final hash = Uint8List.fromList(
      (await Sha256().hash(utf8.encode(session.sessionNonce))).bytes,
    );
    yield* ConversationRepository(database).watchSession(
      userId: session.userId,
      accountEpoch: session.accountEpoch,
      sessionNonceHash: hash,
    );
  }
}
