import '../../features/resources/rag_candidate_contract.dart';
import 'tutor_contract.dart';
import 'tutor_port.dart';

/// Runtime DTOs, not a proposed on-disk manifest/schema or activation authority.
enum DatasetRunMode { product, integrationFixture }

class RagFailure implements Exception {
  const RagFailure(this.code);
  final TutorErrorCode code;
}

class EmbeddingBinding {
  const EmbeddingBinding({
    required this.datasetRevision,
    required this.modelId,
    required this.artifactRevision,
    required this.artifactRelativePath,
    required this.dimension,
    required this.tokenizerId,
    required this.poolingId,
    required this.normalizationId,
  });
  final String datasetRevision,
      modelId,
      artifactRevision,
      artifactRelativePath,
      tokenizerId,
      poolingId,
      normalizationId;
  final int dimension;
  bool get isValid =>
      dimension > 0 &&
      [
        datasetRevision,
        modelId,
        artifactRevision,
        tokenizerId,
        poolingId,
        normalizationId,
      ].every(validIdentity) &&
      !artifactRelativePath.contains(RegExp(r'[\\:\x00]')) &&
      artifactRelativePath
          .split('/')
          .every((s) => s.isNotEmpty && s != '.' && s != '..');
  @override
  bool operator ==(Object other) =>
      other is EmbeddingBinding &&
      datasetRevision == other.datasetRevision &&
      modelId == other.modelId &&
      artifactRevision == other.artifactRevision &&
      artifactRelativePath == other.artifactRelativePath &&
      dimension == other.dimension &&
      tokenizerId == other.tokenizerId &&
      poolingId == other.poolingId &&
      normalizationId == other.normalizationId;
  @override
  int get hashCode => Object.hash(
    datasetRevision,
    modelId,
    artifactRevision,
    artifactRelativePath,
    dimension,
    tokenizerId,
    poolingId,
    normalizationId,
  );
}

bool validIdentity(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

class IndexBinding {
  const IndexBinding({
    required this.embedding,
    required this.type,
    required this.version,
  });
  final EmbeddingBinding embedding;
  final String type, version;
  @override
  bool operator ==(Object other) =>
      other is IndexBinding &&
      embedding == other.embedding &&
      type == other.type &&
      version == other.version;
  @override
  int get hashCode => Object.hash(embedding, type, version);
}

class RuntimePack {
  const RuntimePack({
    required this.packId,
    required this.subjectId,
    required this.index,
  });
  final String packId, subjectId;
  final IndexBinding index;
}

class DatasetRuntimeConfiguration {
  DatasetRuntimeConfiguration({
    required this.revision,
    required this.mode,
    required this.embedding,
    required Iterable<RuntimePack> packs,
    required Iterable<String> expectedSubjectIds,
  }) : packs = List.unmodifiable(packs),
       expectedSubjectIds = List.unmodifiable(expectedSubjectIds);
  final String revision;
  final DatasetRunMode mode;
  final EmbeddingBinding embedding;
  final List<RuntimePack> packs;

  /// Product values must come from the approved catalog, never user selection.
  final List<String> expectedSubjectIds;
  RagCandidateDeclaration get productDeclaration => RagCandidateDeclaration(
    datasetRevision: revision,
    expectedSubjectIds: expectedSubjectIds,
    packs: packs.map(
      (p) => RagPackDeclaration(
        subjectId: p.subjectId,
        datasetRevision: p.index.embedding.datasetRevision,
        embeddingModelId: p.index.embedding.modelId,
        vectorDimensions: p.index.embedding.dimension,
        indexType: p.index.type,
        indexVersion: p.index.version,
      ),
    ),
    sharedEmbedding: SharedEmbeddingDeclaration(
      datasetRevision: embedding.datasetRevision,
      modelId: embedding.modelId,
      vectorDimensions: embedding.dimension,
      tokenizerId: embedding.tokenizerId,
      pooling: embedding.poolingId,
      normalization: embedding.normalizationId,
    ),
    expectedIndexType: packs.first.index.type,
    expectedIndexVersion: packs.first.index.version,
  );
}

abstract interface class QueryEmbedder {
  EmbeddingBinding get configuration;
  Future<List<double>> embed(String text, TutorCancellation cancellation);
}

class RetrievalHit {
  const RetrievalHit({required this.reference, required this.score});
  final SourceReference reference;
  final double score;
}

/// Trusted metadata plus the actual retrieval score; the gate owns its meaning.
class RetrievedChunk extends ResolvedSource {
  RetrievedChunk(ResolvedSource source, {required this.score})
    : super(
        reference: source.reference,
        snippet: source.snippet,
        subject: source.subject,
        unit: source.unit,
        lesson: source.lesson,
        document: source.document,
        page: source.page,
      );
  final double score;
}

abstract interface class IndexPort {
  Map<String, IndexBinding> get bindings;
  Future<List<RetrievalHit>> search(
    List<double> vector,
    Set<String> packIds,
    int topK,
    TutorCancellation cancellation,
  );
}

/// Retains an immutable revision and its actual runtime/index resources until
/// close. Provider verifies files using B07 validators before offering a lease;
/// declaration checks alone can never manufacture such verification/readiness.
abstract interface class RevisionPinnedHandle {
  DatasetRuntimeConfiguration get configuration;
  QueryEmbedder get embedder;
  IndexPort get index;
  Future<ResolvedSource?> resolve(SourceReference reference);
  Future<void> close();
}

abstract interface class DatasetProvider {
  String? get availableRevision;
  DatasetRunMode get mode;

  /// Exact revision only, including historical source requests; no fallback.
  Future<RevisionPinnedHandle?> openRevision(String revision);
}
