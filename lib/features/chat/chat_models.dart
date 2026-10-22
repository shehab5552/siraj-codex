import 'dart:convert';

import 'package:drift/drift.dart' show QueryRow;

import '../../integrations/ai/tutor_contract.dart';

enum ChatPhase {
  loading,
  ready,
  saving,
  asking,
  failed,
  cancelled,
  sessionExpired,
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
  });
  final String id;
  final String title;
  final String createdAt;
}

enum ChatFailureCode {
  invalidQuestion,
  sessionExpired,
  conversationMissing,
  persistenceFailure,
  tutorFailure,
  invalidResponse,
  sourceUnavailable,
  requestCancelled,
  unansweredMessage,
}

class ChatFailure {
  const ChatFailure(this.code, {this.tutorError});
  final ChatFailureCode code;
  final TutorErrorCode? tutorError;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    List<SourceReference> sources = const [],
    this.sourcesUnavailable = false,
  }) : sources = List.unmodifiable(sources);
  final String id;
  final bool isUser;
  final String text;
  final List<SourceReference> sources;
  final bool sourcesUnavailable;

  static ChatMessage fromRow(QueryRow row) {
    final refs = <SourceReference>[];
    var unavailable = false;
    try {
      final raw = jsonDecode(row.read<String>('source_refs_json'));
      if (raw is! List) throw const FormatException('Source array required');
      refs.addAll(raw.map(SourceReference.fromJson));
      if (refs.map((r) => r.datasetRevision).toSet().length > 1 ||
          refs.toSet().length != refs.length) {
        throw const FormatException('Mixed or repeated source identity');
      }
    } on FormatException {
      refs.clear();
      unavailable = true;
    }
    return ChatMessage(
      id: row.read<String>('message_id'),
      isUser: row.read<String>('role') == 'USER',
      text: row.read<String>('content'),
      sources: refs,
      sourcesUnavailable: unavailable,
    );
  }
}
