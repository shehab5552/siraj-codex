import 'package:flutter/foundation.dart';

import '../../features/resources/rag_candidate_contract.dart';
import 'rag_runtime_contract.dart';
import 'tutor_contract.dart';

/// Searches only a provider-owned immutable revision. It never manufactures an
/// evidence decision from similarity scores and never calls ModelRuntime.
class PinnedRetriever {
  const PinnedRetriever({required this.topK});
  final int topK;

  void validate(RevisionPinnedHandle handle) {
    final c = handle.configuration;
    final packs = c.packs;
    if (topK <= 0 ||
        !validIdentity(c.revision) ||
        !c.embedding.isValid ||
        c.embedding.datasetRevision != c.revision ||
        packs.isEmpty ||
        packs.map((p) => p.packId).toSet().length != packs.length ||
        packs.map((p) => p.subjectId).toSet().length != packs.length) {
      _incompatible();
    }
    if (c.mode == DatasetRunMode.integrationFixture &&
        (!kDebugMode || packs.length != 1)) {
      _incompatible();
    }
    if (c.mode == DatasetRunMode.product &&
        !RagCandidateContract.preflight(
          c.productDeclaration,
        ).structureConsistent) {
      _incompatible();
    }
    final indexes = handle.index.bindings;
    if (handle.embedder.configuration != c.embedding ||
        indexes.length != packs.length) {
      _incompatible();
    }
    for (final pack in packs) {
      if (!validIdentity(pack.packId) ||
          !validIdentity(pack.subjectId) ||
          !validIdentity(pack.index.type) ||
          !validIdentity(pack.index.version) ||
          pack.index.embedding != c.embedding ||
          pack.index.type != packs.first.index.type ||
          pack.index.version != packs.first.index.version ||
          indexes[pack.packId] != pack.index) {
        _incompatible();
      }
    }
  }

  Never _incompatible() =>
      throw const RagFailure(TutorErrorCode.resourceNotReady);
  void _current(RevisionPinnedHandle handle, TutorCancellation token) {
    if (token.isCancelled) {
      throw const RagFailure(TutorErrorCode.requestCancelled);
    }
    validate(handle);
  }

  Future<List<RetrievedChunk>> search(
    RevisionPinnedHandle handle,
    String question,
    Set<String> packIds,
    TutorCancellation cancellation,
  ) async {
    _current(handle, cancellation);
    final c = handle.configuration;
    final permitted = c.packs.map((p) => p.packId).toSet();
    final scope = Set<String>.unmodifiable(packIds);
    if (question.trim().isEmpty ||
        scope.isEmpty ||
        !permitted.containsAll(scope)) {
      _incompatible();
    }
    final vector = List<double>.unmodifiable(
      await handle.embedder.embed(question, cancellation),
    );
    _current(handle, cancellation);
    if (vector.length != c.embedding.dimension ||
        vector.any((v) => !v.isFinite)) {
      _incompatible();
    }
    final hits = List<RetrievalHit>.unmodifiable(
      await handle.index.search(vector, scope, topK, cancellation),
    );
    _current(handle, cancellation);
    if (hits.length > topK ||
        hits.map((h) => h.reference).toSet().length != hits.length) {
      _incompatible();
    }
    final results = <RetrievedChunk>[];
    for (final hit in hits) {
      final ref = hit.reference;
      if (!hit.score.isFinite ||
          !ref.isValid ||
          ref.datasetRevision != c.revision ||
          !scope.contains(ref.packId)) {
        _incompatible();
      }
      final source = await handle.resolve(ref);
      _current(handle, cancellation);
      if (source == null ||
          source.reference != ref ||
          source.snippet.trim().isEmpty ||
          (source.page != null && source.page! <= 0)) {
        throw const RagFailure(TutorErrorCode.sourceUnavailable);
      }
      results.add(RetrievedChunk(source, score: hit.score));
    }
    return List.unmodifiable(results);
  }
}
