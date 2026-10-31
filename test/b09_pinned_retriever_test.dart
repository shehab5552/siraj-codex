import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/integrations/ai/pinned_retriever.dart';
import 'package:siraj/integrations/ai/rag_runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';
import 'support/b09_ai_fixture.dart';

void main() {
  late TestHandle h;
  const r = PinnedRetriever(topK: 5);
  setUp(() {
    h = TestHandle();
  });
  Future<List<ResolvedSource>> search([TutorCancellation? c]) => r.search(
    h,
    'synthetic question',
    {'test-pack'},
    c ?? TutorCancellation(),
  );
  test('fixture uses pinned embedder, index and resolved metadata', () async {
    final result = await search();
    expect(result.single.reference, ref);
    expect(result.single.snippet, 'synthetic test text');
    expect(h.embedder.calls, 1);
    expect(h.index.calls, 1);
  });
  test('one fixture pack cannot satisfy product five-pack contract', () async {
    h.configuration = DatasetRuntimeConfiguration(
      revision: 'fixture-r1',
      mode: DatasetRunMode.product,
      embedding: binding,
      packs: h.configuration.packs,
      expectedSubjectIds: ['test-subject'],
    );
    await expectLater(search(), throwsA(isA<RagFailure>()));
    expect(h.embedder.calls, 0);
  });
  for (final dimension in [1, 3]) {
    test('wrong vector dimension $dimension never queries index', () async {
      h.embedder.vector = List.filled(dimension, 1);
      await expectLater(search(), throwsA(isA<RagFailure>()));
      expect(h.index.calls, 0);
    });
  }
  for (final bad in [double.nan, double.infinity]) {
    test('nonfinite vector $bad never queries index', () async {
      h.embedder.vector = [bad, 1];
      await expectLater(search(), throwsA(isA<RagFailure>()));
      expect(h.index.calls, 0);
    });
  }
  test('full preprocessing identity must match actual embedder', () async {
    h.embedder.configuration = const EmbeddingBinding(
      datasetRevision: 'fixture-r1',
      modelId: 'test-embed',
      artifactRevision: 'test-e1',
      artifactRelativePath: 'shared/test.bin',
      dimension: 2,
      tokenizerId: 'DIFFERENT',
      poolingId: 'test-pooling',
      normalizationId: 'test-normalization',
    );
    await expectLater(search(), throwsA(isA<RagFailure>()));
    expect(h.embedder.calls, 0);
  });
  test('index revision binding mismatch fails before embedding', () async {
    h.index.bindings = {};
    await expectLater(search(), throwsA(isA<RagFailure>()));
    expect(h.embedder.calls, 0);
  });
  for (final badRef in [
    const SourceReference(
      packId: 'other',
      chunkId: 'test',
      datasetRevision: 'fixture-r1',
    ),
    const SourceReference(
      packId: 'test-pack',
      chunkId: 'test',
      datasetRevision: 'other',
    ),
  ]) {
    test(
      'reject index hit outside pinned scope ${badRef.packId}/${badRef.datasetRevision}',
      () async {
        h.index.hits = [RetrievalHit(reference: badRef, score: 1)];
        await expectLater(search(), throwsA(isA<RagFailure>()));
      },
    );
  }
  test('duplicate hits are rejected', () async {
    h.index.hits.add(h.index.hits.first);
    await expectLater(search(), throwsA(isA<RagFailure>()));
  });
  test('missing metadata is source unavailable, not fabricated', () async {
    h.resolver = (_) => null;
    await expectLater(
      search(),
      throwsA(
        isA<RagFailure>().having(
          (e) => e.code,
          'code',
          TutorErrorCode.sourceUnavailable,
        ),
      ),
    );
  });
  test('cancel during embedding prevents index access', () async {
    h.embedder.paused = Completer<List<double>>();
    final token = TutorCancellation();
    final future = search(token);
    final failure = expectLater(
      future,
      throwsA(
        isA<RagFailure>().having(
          (e) => e.code,
          'code',
          TutorErrorCode.requestCancelled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    h.embedder.paused!.complete([1, 0]);
    await failure;
    expect(h.index.calls, 0);
  });
  test('scope must be nonempty and declared', () async {
    await expectLater(
      r.search(h, 'q', {'other'}, TutorCancellation()),
      throwsA(isA<RagFailure>()),
    );
    expect(h.embedder.calls, 0);
  });
  test('actual index score reaches the evidence boundary', () async {
    expect(
      (await search()).single,
      isA<RetrievedChunk>().having((chunk) => chunk.score, 'score', 0.8),
    );
  });
  for (final changed in [
    'model',
    'artifact_revision',
    'path',
    'dimension',
    'tokenizer',
    'pooling',
    'normalization',
    'dataset_revision',
  ]) {
    test(
      'reject changed shared binding $changed despite other equal fields',
      () async {
        h.embedder.configuration = EmbeddingBinding(
          datasetRevision: changed == 'dataset_revision'
              ? 'other'
              : binding.datasetRevision,
          modelId: changed == 'model' ? 'other' : binding.modelId,
          artifactRevision: changed == 'artifact_revision'
              ? 'other'
              : binding.artifactRevision,
          artifactRelativePath: changed == 'path'
              ? 'other.bin'
              : binding.artifactRelativePath,
          dimension: changed == 'dimension' ? 3 : binding.dimension,
          tokenizerId: changed == 'tokenizer' ? 'other' : binding.tokenizerId,
          poolingId: changed == 'pooling' ? 'other' : binding.poolingId,
          normalizationId: changed == 'normalization'
              ? 'other'
              : binding.normalizationId,
        );
        await expectLater(search(), throwsA(isA<RagFailure>()));
        expect(h.embedder.calls, 0);
      },
    );
  }
  test(
    'five structurally compatible declarations pass without granting RAG_READY',
    () {
      final packs = List.generate(
        5,
        (i) => RuntimePack(
          packId: 'pack-$i',
          subjectId: 'subject-$i',
          index: indexBinding,
        ),
      );
      h.configuration = DatasetRuntimeConfiguration(
        revision: 'fixture-r1',
        mode: DatasetRunMode.product,
        embedding: binding,
        packs: packs,
        expectedSubjectIds: packs.map((p) => p.subjectId),
      );
      h.index.bindings = {for (final p in packs) p.packId: p.index};
      expect(() => r.validate(h), returnsNormally);
      expect(
        h.embedder.calls,
        0,
      ); // structural binding check only, not a device vector proof
    },
  );
  test('nonfinite index scores and extra hits are rejected', () async {
    h.index.hits = [const RetrievalHit(reference: ref, score: double.nan)];
    await expectLater(search(), throwsA(isA<RagFailure>()));
    h.index.hits = List.generate(
      6,
      (i) => RetrievalHit(
        reference: SourceReference(
          packId: 'test-pack',
          chunkId: 'chunk-$i',
          datasetRevision: 'fixture-r1',
        ),
        score: 1,
      ),
    );
    await expectLater(search(), throwsA(isA<RagFailure>()));
  });
  test(
    'source metadata cannot substitute a new revision or invent a page',
    () async {
      h.resolver = (_) =>
          const ResolvedSource(reference: ref, snippet: 'test', page: 0);
      await expectLater(
        search(),
        throwsA(
          isA<RagFailure>().having(
            (e) => e.code,
            'code',
            TutorErrorCode.sourceUnavailable,
          ),
        ),
      );
    },
  );
}
