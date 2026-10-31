import 'rag_runtime_contract.dart';
import 'runtime_contract.dart';
import 'tutor_contract.dart';
import 'tutor_port.dart';

class ScopeSelection {
  ScopeSelection(Iterable<String> packIds)
    : packIds = Set.unmodifiable(packIds);
  final Set<String> packIds;
  bool get needsClarification => packIds.isEmpty;
}

abstract interface class ScopeResolver {
  Future<ScopeSelection> resolve(
    TutorRequest request,
    DatasetRuntimeConfiguration dataset,
    TutorCancellation cancellation,
  );
}

enum EvidenceDecision { full, partialIndependent, insufficient, ambiguous }

class EvidenceAssessment {
  EvidenceAssessment({
    required this.decision,
    Iterable<SourceReference> approvedSources = const [],
    Iterable<String> supportedSubparts = const [],
    Iterable<String> unsupportedSubparts = const [],
  }) : approvedSources = List.unmodifiable(approvedSources),
       supportedSubparts = List.unmodifiable(supportedSubparts),
       unsupportedSubparts = List.unmodifiable(unsupportedSubparts);
  final EvidenceDecision decision;
  final List<SourceReference> approvedSources;
  final List<String> supportedSubparts, unsupportedSubparts;
}

/// Mandatory approved A/C policy. Similarity, a matching ID or nonempty text is
/// not automatically scientific evidence. No permissive default is provided.
abstract interface class EvidenceGate {
  Future<EvidenceAssessment> evaluate(
    TutorRequest request,
    List<RetrievedChunk> retrieved,
    TutorCancellation cancellation,
  );
}

abstract interface class TutorPromptBuilder {
  /// Use approved profile/tokenizer and budget; history is context, not evidence.
  Future<GenerationRequest> prepare(
    TutorRequest request,
    List<ResolvedSource> approved,
    EvidenceAssessment evidence,
    ModelConfig model,
    TutorCancellation cancellation,
  );
}

abstract interface class AnswerValidator {
  /// Includes available deterministic checks, partial-disclosure and approved
  /// source selection. Not proof of semantic entailment for every claim.
  Future<TutorResult> validate(
    TutorRequest request,
    String generated,
    List<ResolvedSource> approved,
    EvidenceAssessment evidence,
    TutorCancellation cancellation,
  );
}
