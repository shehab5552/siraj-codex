import 'dart:async';
import 'package:siraj/integrations/ai/rag_runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';

const binding = EmbeddingBinding(
  datasetRevision: 'fixture-r1',
  modelId: 'test-embed',
  artifactRevision: 'test-e1',
  artifactRelativePath: 'shared/test.bin',
  dimension: 2,
  tokenizerId: 'test-tokenizer',
  poolingId: 'test-pooling',
  normalizationId: 'test-normalization',
);
const indexBinding = IndexBinding(
  embedding: binding,
  type: 'test-index',
  version: 'test-v1',
);
const ref = SourceReference(
  packId: 'test-pack',
  chunkId: 'test-chunk',
  datasetRevision: 'fixture-r1',
);

class TestEmbedder implements QueryEmbedder {
  @override
  EmbeddingBinding configuration = binding;
  List<double> vector = [1, 0];
  int calls = 0;
  Completer<List<double>>? paused;
  @override
  Future<List<double>> embed(
    String text,
    TutorCancellation cancellation,
  ) async {
    calls++;
    return paused == null ? vector : paused!.future;
  }
}

class TestIndex implements IndexPort {
  @override
  Map<String, IndexBinding> bindings = {'test-pack': indexBinding};
  List<RetrievalHit> hits = [const RetrievalHit(reference: ref, score: 0.8)];
  int calls = 0;
  @override
  Future<List<RetrievalHit>> search(
    List<double> vector,
    Set<String> packIds,
    int topK,
    TutorCancellation cancellation,
  ) async {
    calls++;
    return hits;
  }
}

class TestHandle implements RevisionPinnedHandle {
  @override
  DatasetRuntimeConfiguration configuration = DatasetRuntimeConfiguration(
    revision: 'fixture-r1',
    mode: DatasetRunMode.integrationFixture,
    embedding: binding,
    packs: [
      const RuntimePack(
        packId: 'test-pack',
        subjectId: 'test-subject',
        index: indexBinding,
      ),
    ],
    expectedSubjectIds: ['test-subject'],
  );
  @override
  final TestEmbedder embedder = TestEmbedder();
  @override
  final TestIndex index = TestIndex();
  int closed = 0;
  FutureOr<ResolvedSource?> Function(SourceReference)? resolver;
  @override
  Future<ResolvedSource?> resolve(SourceReference reference) async =>
      resolver == null
      ? ResolvedSource(
          reference: reference,
          snippet: 'synthetic test text',
          subject: 'test subject',
        )
      : await resolver!(reference);
  @override
  Future<void> close() async {
    closed++;
  }
}

class TestDatasets implements DatasetProvider {
  @override
  String? availableRevision = 'fixture-r1';
  @override
  DatasetRunMode mode = DatasetRunMode.integrationFixture;
  TestHandle handle = TestHandle();
  final opened = <String>[];
  @override
  Future<RevisionPinnedHandle?> openRevision(String revision) async {
    opened.add(revision);
    return revision == handle.configuration.revision ? handle : null;
  }
}
