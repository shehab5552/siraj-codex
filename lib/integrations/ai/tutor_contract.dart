import 'dart:async';

enum TutorStatus { answer, refusal, error }

enum TutorReason { partialEvidence, noEvidence, needsScopeClarification }

enum TutorErrorCode {
  resourceNotReady,
  modelLoadFailed,
  generationFailed,
  requestCancelled,
  outOfMemory,
  invalidResponse,
  sourceUnavailable,
}

class SourceReference {
  const SourceReference({
    required this.packId,
    required this.chunkId,
    required this.datasetRevision,
  });
  final String packId;
  final String chunkId;
  final String datasetRevision;
  bool get isValid => [packId, chunkId, datasetRevision].every(
    (value) =>
        value.isNotEmpty &&
        value == value.trim() &&
        !RegExp(r'[\x00-\x1f]').hasMatch(value),
  );
  Map<String, String> toJson() => {
    'pack_id': packId,
    'chunk_id': chunkId,
    'dataset_revision': datasetRevision,
  };
  static SourceReference fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['pack_id'] is! String ||
        raw['chunk_id'] is! String ||
        raw['dataset_revision'] is! String) {
      throw const FormatException('Invalid source reference');
    }
    final reference = SourceReference(
      packId: raw['pack_id'] as String,
      chunkId: raw['chunk_id'] as String,
      datasetRevision: raw['dataset_revision'] as String,
    );
    if (!reference.isValid) {
      throw const FormatException('Invalid source identity');
    }
    return reference;
  }

  @override
  bool operator ==(Object other) =>
      other is SourceReference &&
      packId == other.packId &&
      chunkId == other.chunkId &&
      datasetRevision == other.datasetRevision;
  @override
  int get hashCode => Object.hash(packId, chunkId, datasetRevision);
}

class TutorResult {
  TutorResult({
    required this.status,
    this.text,
    List<SourceReference> sources = const [],
    this.reason,
    this.error,
  }) : sources = List.unmodifiable(sources);
  factory TutorResult.answer(
    String text,
    List<SourceReference> sources, {
    bool partial = false,
  }) => TutorResult(
    status: TutorStatus.answer,
    text: text,
    sources: sources,
    reason: partial ? TutorReason.partialEvidence : null,
  );
  factory TutorResult.refusal(TutorReason reason) =>
      TutorResult(status: TutorStatus.refusal, reason: reason);
  factory TutorResult.error(TutorErrorCode code) =>
      TutorResult(status: TutorStatus.error, error: code);
  final TutorStatus status;
  final String? text;
  final List<SourceReference> sources;
  final TutorReason? reason;
  final TutorErrorCode? error;
  bool get isPartial =>
      status == TutorStatus.answer && reason == TutorReason.partialEvidence;
}

class TutorCancellation {
  final _signal = Completer<void>();
  bool get isCancelled => _signal.isCompleted;
  Future<void> get whenCancelled => _signal.future;
  void cancel() {
    if (!_signal.isCompleted) _signal.complete();
  }
}

class TutorContextMessage {
  const TutorContextMessage({required this.role, required this.text});
  final String role;
  final String text;
}

class TutorRequest {
  TutorRequest({
    required this.requestId,
    required this.userId,
    required this.accountEpoch,
    required this.conversationId,
    required this.question,
    required this.datasetRevision,
    required this.cancellation,
    List<TutorContextMessage> history = const [],
  }) : history = List.unmodifiable(history);
  final String requestId;
  final String userId;
  final String accountEpoch;
  final String conversationId;
  final String question;
  final String? datasetRevision;
  final TutorCancellation cancellation;
  final List<TutorContextMessage> history;
}

class TutorReply {
  TutorReply({
    required this.requestId,
    required this.userId,
    required this.accountEpoch,
    required this.conversationId,
    required this.datasetRevision,
    required this.result,
    List<SourceReference> approvedSources = const [],
  }) : approvedSources = List.unmodifiable(approvedSources);
  final String requestId;
  final String userId;
  final String accountEpoch;
  final String conversationId;
  final String? datasetRevision;
  final List<SourceReference> approvedSources;
  final TutorResult result;

  /// The adapter must obtain approvedSources from retrieval/evidence, never
  /// from model text. This checks identity/shape, not semantic grounding.
  TutorResult checkedFor(TutorRequest request) {
    if (requestId != request.requestId ||
        userId != request.userId ||
        accountEpoch != request.accountEpoch ||
        conversationId != request.conversationId ||
        datasetRevision != request.datasetRevision) {
      throw const TutorContractFailure();
    }
    switch (result.status) {
      case TutorStatus.answer:
        final revision = request.datasetRevision;
        if (revision == null ||
            revision.trim().isEmpty ||
            result.text == null ||
            result.text!.trim().isEmpty ||
            result.sources.isEmpty ||
            result.error != null ||
            (result.reason != null &&
                result.reason != TutorReason.partialEvidence)) {
          throw const TutorContractFailure();
        }
        final approved = approvedSources.toSet();
        if (approved.any(
              (ref) => !ref.isValid || ref.datasetRevision != revision,
            ) ||
            result.sources.toSet().length != result.sources.length ||
            result.sources.any(
              (ref) =>
                  !ref.isValid ||
                  ref.datasetRevision != revision ||
                  !approved.contains(ref),
            )) {
          throw const TutorContractFailure();
        }
      case TutorStatus.refusal:
        if (result.sources.isNotEmpty ||
            result.error != null ||
            ![
              TutorReason.noEvidence,
              TutorReason.needsScopeClarification,
            ].contains(result.reason)) {
          throw const TutorContractFailure();
        }
      case TutorStatus.error:
        if (result.sources.isNotEmpty ||
            result.error == null ||
            result.reason != null) {
          throw const TutorContractFailure();
        }
    }
    return result;
  }
}

class TutorContractFailure implements Exception {
  const TutorContractFailure();
}
