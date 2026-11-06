import '../ai_runtime/ai_runtime_client.dart';

/// Official P0 DD-10: references are assigned by retrieval, never by the LLM.
class SourceReference {
  SourceReference({
    required this.packId,
    required this.chunkId,
    required this.datasetRevision,
  }) {
    if ([
      packId,
      chunkId,
      datasetRevision,
    ].any((s) => s.trim().isEmpty || s.trim() != s)) {
      throw ArgumentError('Invalid reference identity');
    }
  }
  final String packId, chunkId, datasetRevision;
  Map<String, String> toJson() => {
    'pack_id': packId,
    'chunk_id': chunkId,
    'dataset_revision': datasetRevision,
  };
}

enum TutorStatus { answer, refusal, error }

enum TutorReason {
  noEvidence,
  sourceUnavailable,
  resourcesUnavailable,
  runtimeUnavailable,
  generationFailed,
  cancelled,
  sessionInvalid,
  conversationUnavailable,
  persistenceFailure,
}

class TutorResult {
  TutorResult._(
    this.status,
    this.text,
    this.sources,
    this.reason,
    this.isPartial,
  );
  factory TutorResult.answer(
    String text,
    List<SourceReference> sources, {
    bool isPartial = false,
  }) {
    if (text.trim().isEmpty ||
        sources.isEmpty ||
        sources.map((s) => s.datasetRevision).toSet().length != 1) {
      throw ArgumentError('Unverifiable answer');
    }
    return TutorResult._(
      TutorStatus.answer,
      text,
      List.unmodifiable(sources),
      null,
      isPartial,
    );
  }
  factory TutorResult.refusal(TutorReason reason) =>
      TutorResult._(TutorStatus.refusal, '', const [], reason, false);
  factory TutorResult.error(TutorReason reason) =>
      TutorResult._(TutorStatus.error, '', const [], reason, false);
  final TutorStatus status;
  final String text;
  final List<SourceReference> sources;
  final TutorReason? reason;

  /// FR-05: partial is an ANSWER attribute, not a fourth Tutor status.
  final bool isPartial;
}

class TutorCancellation {
  bool _cancelled = false;
  void Function()? onCancel;
  bool get isCancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    onCancel?.call();
  }
}

abstract interface class TutorPort {
  Future<TutorResult> ask(String question, TutorCancellation cancellation);
  bool isRevisionCurrent(String revision);
}

class GroundedContext {
  GroundedContext({
    required this.systemInstruction,
    required this.prompt,
    required List<SourceReference> sources,
    required this.revision,
  }) : sources = List.unmodifiable(sources) {
    if (systemInstruction.trim().isEmpty ||
        prompt.trim().isEmpty ||
        revision.isEmpty ||
        sources.isEmpty ||
        sources.any((s) => s.datasetRevision != revision)) {
      throw ArgumentError('Unverified context');
    }
  }
  final String systemInstruction, prompt, revision;
  final List<SourceReference> sources;
}

/// A/C seam: approved scope/retrieval/prompt/evidence and deterministic postchecks.
/// No default scientific threshold, prefix, partial-selection or source policy.
abstract interface class TutorEvidencePort {
  Future<GroundedContext?> prepare(
    String question,
    TutorCancellation cancellation,
  );
  Future<bool> validateAnswer(GroundedContext context, String answer);
  bool isRevisionCurrent(String revision);
}

class UnavailableTutorEvidence implements TutorEvidencePort {
  const UnavailableTutorEvidence();
  @override
  Future<GroundedContext?> prepare(
    String question,
    TutorCancellation cancellation,
  ) async =>
      throw const AiRuntimeFailure(AiRuntimeErrorCode.resourceUnavailable);
  @override
  Future<bool> validateAnswer(GroundedContext context, String answer) async =>
      false;
  @override
  bool isRevisionCurrent(String revision) => false;
}
