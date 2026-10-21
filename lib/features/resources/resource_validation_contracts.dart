/// B-07 Step 3 — validation REQUIREMENTS, not a file validator or a READY gate.
///
/// Only specialized trusted validators may supply evidence for these checks.
/// This module performs no I/O, hash calculation, parsing or SQLite writes.
/// In particular, checklist coverage must NEVER be interpreted as READY/ACTIVE.
enum ResourceValidationCheck {
  transferComplete,
  sha256Matched,
  supportedModelFormat,
  runtimeCompatible,
  deviceCompatible,
  modelLoadProven,
  safeArchiveExtraction,
  archiveIntegrity,
  validPackSchema,
  validChunkReferences,
  validIndexFormat,
  validIndexVersion,
  embeddingModelCompatible,
  tokenizerCompatible,
  poolingCompatible,
  normalizationCompatible,
  vectorDimensionsCompatible,
  androidSampleQueryPassed,
  pdfReadable,
}

/// Public DB kind strings are preserved; no additional resource type is added.
enum ResourceContractKind {
  llm('LLM'),
  ragPack('RAG_PACK'),
  ragEmbedding('RAG_EMBEDDING'),
  pdf('PDF');

  const ResourceContractKind(this.dbKind);
  final String dbKind;
}

class ResourceValidationRequirements {
  const ResourceValidationRequirements._();

  static Set<ResourceValidationCheck> forKind(
    ResourceContractKind kind, {
    bool pdfCatalogHashProvided = false,
  }) {
    final checks = switch (kind) {
      ResourceContractKind.llm => <ResourceValidationCheck>{
        ResourceValidationCheck.transferComplete,
        ResourceValidationCheck.sha256Matched,
        ResourceValidationCheck.supportedModelFormat,
        ResourceValidationCheck.runtimeCompatible,
        ResourceValidationCheck.deviceCompatible,
        ResourceValidationCheck.modelLoadProven,
      },
      ResourceContractKind.ragPack => <ResourceValidationCheck>{
        ResourceValidationCheck.transferComplete,
        ResourceValidationCheck.sha256Matched,
        ResourceValidationCheck.safeArchiveExtraction,
        ResourceValidationCheck.archiveIntegrity,
        ResourceValidationCheck.validPackSchema,
        ResourceValidationCheck.validChunkReferences,
        ResourceValidationCheck.validIndexFormat,
        ResourceValidationCheck.validIndexVersion,
        ResourceValidationCheck.vectorDimensionsCompatible,
      },
      ResourceContractKind.ragEmbedding => <ResourceValidationCheck>{
        ResourceValidationCheck.transferComplete,
        ResourceValidationCheck.sha256Matched,
        ResourceValidationCheck.embeddingModelCompatible,
        ResourceValidationCheck.tokenizerCompatible,
        ResourceValidationCheck.poolingCompatible,
        ResourceValidationCheck.normalizationCompatible,
        ResourceValidationCheck.vectorDimensionsCompatible,
        ResourceValidationCheck.androidSampleQueryPassed,
      },
      ResourceContractKind.pdf => <ResourceValidationCheck>{
        ResourceValidationCheck.transferComplete,
        ResourceValidationCheck.pdfReadable,
        if (pdfCatalogHashProvided) ResourceValidationCheck.sha256Matched,
      },
    };
    return Set<ResourceValidationCheck>.unmodifiable(checks);
  }

  /// Audits only the *inventory* of evidence supplied by future validators.
  ///
  /// A full checklist is NOT verification of the underlying bytes, proof of
  /// compatibility, successful activation, or permission to set READY.
  static ResourceEvidenceInventory audit({
    required ResourceContractKind kind,
    required Set<ResourceValidationCheck> reportedPassed,
    Set<ResourceValidationCheck> reportedFailed = const {},
    bool pdfCatalogHashProvided = false,
  }) {
    final requiredChecks = forKind(
      kind,
      pdfCatalogHashProvided: pdfCatalogHashProvided,
    );
    final contradictions = reportedPassed.intersection(reportedFailed);
    final unknown = {
      ...reportedPassed,
      ...reportedFailed,
    }.difference(requiredChecks);
    final outstanding = requiredChecks.difference(reportedPassed);
    return ResourceEvidenceInventory._(
      requiredChecks: requiredChecks,
      outstanding: Set.unmodifiable(outstanding),
      failed: Set.unmodifiable(reportedFailed.intersection(requiredChecks)),
      contradictory: Set.unmodifiable(contradictions),
      unexpected: Set.unmodifiable(unknown),
    );
  }
}

class ResourceEvidenceInventory {
  const ResourceEvidenceInventory._({
    required this.requiredChecks,
    required this.outstanding,
    required this.failed,
    required this.contradictory,
    required this.unexpected,
  });

  final Set<ResourceValidationCheck> requiredChecks;
  final Set<ResourceValidationCheck> outstanding;
  final Set<ResourceValidationCheck> failed;
  final Set<ResourceValidationCheck> contradictory;
  final Set<ResourceValidationCheck> unexpected;

  /// Only means check NAMES have been supplied without gaps or contradictions.
  /// Never use this to infer READY, ACTIVE, RAG_READY or file validity.
  bool get evidenceListComplete =>
      outstanding.isEmpty &&
      failed.isEmpty &&
      contradictory.isEmpty &&
      unexpected.isEmpty;
}
