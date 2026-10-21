/// B-07 Step 3 — pure structural preflight for a candidate RAG manifest.
///
/// This checks declared IDs/revisions/config only. It does not inspect files,
/// verify hashes, run embeddings, promote releases, or change the active pointer.
/// Passing preflight is NEVER equivalent to RAG_READY or ACTIVE.
class RagPackDeclaration {
  const RagPackDeclaration({
    required this.subjectId,
    required this.datasetRevision,
    required this.embeddingModelId,
    required this.vectorDimensions,
    required this.indexType,
    required this.indexVersion,
  });

  final String subjectId;
  final String datasetRevision;
  final String embeddingModelId;
  final int vectorDimensions;
  final String indexType;
  final String indexVersion;
}

class SharedEmbeddingDeclaration {
  const SharedEmbeddingDeclaration({
    required this.datasetRevision,
    required this.modelId,
    required this.vectorDimensions,
    required this.tokenizerId,
    required this.pooling,
    required this.normalization,
  });

  final String datasetRevision;
  final String modelId;
  final int vectorDimensions;
  final String tokenizerId;
  final String pooling;
  final String normalization;
}

class RagCandidateDeclaration {
  RagCandidateDeclaration({
    required this.datasetRevision,
    required Iterable<String> expectedSubjectIds,
    required Iterable<RagPackDeclaration> packs,
    required this.sharedEmbedding,
    required this.expectedIndexType,
    required this.expectedIndexVersion,
  }) : expectedSubjectIds = List.unmodifiable(expectedSubjectIds),
       packs = List.unmodifiable(packs);

  final String datasetRevision;

  /// Must be supplied from the approved subject catalog (not user input).
  final List<String> expectedSubjectIds;
  final List<RagPackDeclaration> packs;
  final SharedEmbeddingDeclaration? sharedEmbedding;
  final String expectedIndexType;
  final String expectedIndexVersion;
}

enum RagCandidateIssue {
  invalidRevision,
  invalidSubjectCatalog,
  missingPack,
  duplicatePack,
  unexpectedPack,
  invalidPackIdentity,
  packRevisionMismatch,
  missingSharedEmbedding,
  sharedEmbeddingRevisionMismatch,
  embeddingIdentityMismatch,
  invalidEmbeddingConfig,
  vectorDimensionsMismatch,
  indexConfigMismatch,
}

class RagCandidatePreflightResult {
  RagCandidatePreflightResult(Set<RagCandidateIssue> issues)
    : issues = Set.unmodifiable(issues);

  final Set<RagCandidateIssue> issues;

  /// Manifest structure only; NOT evidence of actual on-device validity.
  bool get structureConsistent => issues.isEmpty;
}

class RagCandidateContract {
  const RagCandidateContract._();

  static RagCandidatePreflightResult preflight(
    RagCandidateDeclaration candidate,
  ) {
    final issues = <RagCandidateIssue>{};
    bool blank(String value) => value.trim().isEmpty;

    if (blank(candidate.datasetRevision)) {
      issues.add(RagCandidateIssue.invalidRevision);
    }

    final expected = candidate.expectedSubjectIds.toSet();
    if (candidate.expectedSubjectIds.length != 5 ||
        expected.length != 5 ||
        expected.any(blank)) {
      issues.add(RagCandidateIssue.invalidSubjectCatalog);
    }

    final subjectCounts = <String, int>{};
    for (final pack in candidate.packs) {
      subjectCounts.update(
        pack.subjectId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (blank(pack.subjectId) || blank(pack.embeddingModelId)) {
        issues.add(RagCandidateIssue.invalidPackIdentity);
      }
      if (pack.datasetRevision != candidate.datasetRevision) {
        issues.add(RagCandidateIssue.packRevisionMismatch);
      }
      if (pack.indexType != candidate.expectedIndexType ||
          pack.indexVersion != candidate.expectedIndexVersion ||
          blank(pack.indexType) ||
          blank(pack.indexVersion)) {
        issues.add(RagCandidateIssue.indexConfigMismatch);
      }
    }

    if (candidate.packs.length != 5 ||
        expected.any((subject) => !subjectCounts.containsKey(subject))) {
      issues.add(RagCandidateIssue.missingPack);
    }
    if (subjectCounts.values.any((count) => count > 1)) {
      issues.add(RagCandidateIssue.duplicatePack);
    }
    if (subjectCounts.keys.any((subject) => !expected.contains(subject))) {
      issues.add(RagCandidateIssue.unexpectedPack);
    }
    if (blank(candidate.expectedIndexType) ||
        blank(candidate.expectedIndexVersion)) {
      issues.add(RagCandidateIssue.indexConfigMismatch);
    }

    final embedding = candidate.sharedEmbedding;
    if (embedding == null) {
      issues.add(RagCandidateIssue.missingSharedEmbedding);
    } else {
      if (embedding.datasetRevision != candidate.datasetRevision) {
        issues.add(RagCandidateIssue.sharedEmbeddingRevisionMismatch);
      }
      if (blank(embedding.modelId) ||
          blank(embedding.tokenizerId) ||
          blank(embedding.pooling) ||
          blank(embedding.normalization) ||
          embedding.vectorDimensions <= 0) {
        issues.add(RagCandidateIssue.invalidEmbeddingConfig);
      }
      for (final pack in candidate.packs) {
        if (pack.embeddingModelId != embedding.modelId) {
          issues.add(RagCandidateIssue.embeddingIdentityMismatch);
        }
        if (pack.vectorDimensions != embedding.vectorDimensions ||
            pack.vectorDimensions <= 0) {
          issues.add(RagCandidateIssue.vectorDimensionsMismatch);
        }
      }
    }

    return RagCandidatePreflightResult(issues);
  }
}
