import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/integrations/ai/managed_query_embedder.dart';
import 'package:siraj/integrations/ai/runtime_contract.dart';
import 'package:siraj/integrations/ai/shared_embedding_runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/rag_runtime_contract.dart';
import 'package:siraj/integrations/ai/pinned_retriever.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';
import 'support/b09_ai_fixture.dart' as rag;
import 'support/shared_embedding_fixture.dart';

/// Deterministic deadline only for the timeout test; real artifact IO remains
/// real, while OS scheduling cannot accidentally time out its preload phase.
class _DeadlineTimer implements Timer {
  _DeadlineTimer(this._callback);
  final void Function() _callback;
  bool _active = true;
  int _tick = 0;
  @override
  bool get isActive => _active;
  @override
  int get tick => _tick;
  @override
  void cancel() => _active = false;
  void fire() {
    if (!_active) return;
    _active = false;
    _tick = 1;
    _callback();
  }
}

class EmbeddingHandle implements RevisionPinnedHandle {
  EmbeddingHandle(this.embedder);
  final rag.TestHandle delegate = rag.TestHandle();
  @override
  final QueryEmbedder embedder;
  @override
  DatasetRuntimeConfiguration get configuration => delegate.configuration;
  @override
  IndexPort get index => delegate.index;
  @override
  Future<ResolvedSource?> resolve(SourceReference ref) => delegate.resolve(ref);
  @override
  Future<void> close() async {}
}

Matcher failure(RuntimeErrorCode code) =>
    throwsA(isA<RuntimeFailure>().having((e) => e.code, 'code', code));
void main() {
  late EmbeddingFixture f;
  late ManagedQueryEmbedder embedder;
  setUp(() async {
    f = EmbeddingFixture();
    await f.initialize();
    embedder = ManagedQueryEmbedder(
      config: f.config,
      backend: f.backend,
      operationTimeout: const Duration(seconds: 1),
    );
  });
  tearDown(() async {
    await embedder.whenIdle;
    await embedder.unload();
    await f.close();
  });
  test(
    'verified immutable revision loads and returns a fresh immutable vector',
    () async {
      await embedder.load(TutorCancellation());
      expect(embedder.state, EmbeddingRuntimeState.ready);
      final first = await embedder.embed('test question', TutorCancellation());
      expect(first, [1, 0]);
      expect(() => first[0] = 5, throwsUnsupportedError);
      await embedder.embed('follow-up', TutorCancellation());
      expect(f.backend.requests.map((r) => r.text), [
        'test question',
        'follow-up',
      ]);
      expect(f.backend.requests.map((r) => r.requestId).toSet().length, 2);
      expect(embedder.configuration, f.config.binding);
    },
  );
  test(
    'unavailable backend returns an operational error without a fake vector',
    () async {
      final unavailable = ManagedQueryEmbedder(
        config: f.config,
        operationTimeout: const Duration(seconds: 1),
      );
      try {
        await expectLater(
          unavailable.load(TutorCancellation()),
          failure(RuntimeErrorCode.notReady),
        );
        await expectLater(
          unavailable.embed('test', TutorCancellation()),
          failure(RuntimeErrorCode.notReady),
        );
      } finally {
        await unavailable.whenIdle;
        await unavailable.unload();
      }
    },
  );
  test('corrupt tokenizer sidecar prevents any native load', () async {
    await File(
      '${f.directory.path}/shared/tokenizer.cfg',
    ).writeAsString('corrupt');
    await expectLater(
      embedder.load(TutorCancellation()),
      failure(RuntimeErrorCode.incompatible),
    );
    expect(f.backend.events, isEmpty);
  });
  test(
    'partial or failed native load requires successful unload before reuse',
    () async {
      f.backend.loadError = StateError('native detail must not escape');
      await expectLater(
        embedder.load(TutorCancellation()),
        failure(RuntimeErrorCode.loadFailed),
      );
      await expectLater(
        embedder.load(TutorCancellation()),
        failure(RuntimeErrorCode.notReady),
      );
      await embedder.unload();
      f.backend.loadError = null;
      await embedder.load(TutorCancellation());
      expect(embedder.state, EmbeddingRuntimeState.ready);
    },
  );
  for (final vector in <List<double>>[
    [],
    [1],
    [1, double.nan],
    [double.infinity, 0],
  ]) {
    test('rejects invalid vector dimension/nonfinite output $vector', () async {
      f.backend.vector = vector;
      await embedder.load(TutorCancellation());
      await expectLater(
        embedder.embed('test', TutorCancellation()),
        failure(RuntimeErrorCode.invalidOutput),
      );
      expect(embedder.state, EmbeddingRuntimeState.error);
    });
  }
  test('empty query does not consume the ready native lane', () async {
    await embedder.load(TutorCancellation());
    await expectLater(
      embedder.embed('  ', TutorCancellation()),
      failure(RuntimeErrorCode.incompatible),
    );
    expect(embedder.state, EmbeddingRuntimeState.ready);
    expect(f.backend.requests, isEmpty);
  });
  test(
    'cancellation returns logically but retains native ownership until drainage',
    () async {
      await embedder.load(TutorCancellation());
      f.backend.pending = Completer<List<double>>();
      final token = TutorCancellation();
      final work = embedder.embed('test', token);
      final result = expectLater(work, failure(RuntimeErrorCode.cancelled));
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await result;
      await expectLater(embedder.unload(), failure(RuntimeErrorCode.busy));
      await expectLater(
        embedder.embed('second', TutorCancellation()),
        failure(RuntimeErrorCode.busy),
      );
      f.backend.pending!.complete([1, 0]);
      await embedder.whenIdle;
      await embedder.unload();
      expect(embedder.state, EmbeddingRuntimeState.notLoaded);
    },
  );
  test(
    'stalled native cancel does not block the logical cancelled result',
    () async {
      await embedder.load(TutorCancellation());
      f.backend.pending = Completer<List<double>>();
      f.backend.cancelDrain = Completer<void>();
      final token = TutorCancellation();
      final result = expectLater(
        embedder.embed('test', token),
        failure(RuntimeErrorCode.cancelled),
      );
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await result.timeout(const Duration(milliseconds: 300));
      f.backend.pending!.complete([1, 0]);
      await expectLater(embedder.unload(), failure(RuntimeErrorCode.busy));
      f.backend.cancelDrain!.complete();
      await embedder.whenIdle;
    },
  );
  test('native OOM stays typed and blocks inference until recovery', () async {
    await embedder.load(TutorCancellation());
    f.backend.embedError = const RuntimeFailure(RuntimeErrorCode.outOfMemory);
    await expectLater(
      embedder.embed('test', TutorCancellation()),
      failure(RuntimeErrorCode.outOfMemory),
    );
    await expectLater(
      embedder.embed('again', TutorCancellation()),
      failure(RuntimeErrorCode.notReady),
    );
  });
  test(
    'unapproved normalization is never applied to backend vectors',
    () async {
      f.backend.vector = [2, 0];
      await embedder.load(TutorCancellation());
      expect(await embedder.embed('test', TutorCancellation()), [2, 0]);
    },
  );
  test(
    'existing pinned retriever consumes the managed shared embedder contract',
    () async {
      await embedder.load(TutorCancellation());
      final chunks = await const PinnedRetriever(topK: 1).search(
        EmbeddingHandle(embedder),
        'test question',
        {'test-pack'},
        TutorCancellation(),
      );
      expect(chunks.single.reference, rag.ref);
      expect(chunks.single.snippet, 'synthetic test text');
    },
  );
  for (final field in [
    'runtime',
    'revision',
    'artifact',
    'tokenizer',
    'pooling',
    'normalization',
    'dimension',
  ]) {
    test('backend capability mismatch in $field never becomes ready', () async {
      final b = rag.binding;
      f.backend.capabilities = EmbeddingCapabilities(
        runtimeId: field == 'runtime' ? 'OTHER' : f.config.runtimeId,
        binding: EmbeddingBinding(
          datasetRevision: field == 'revision' ? 'other' : b.datasetRevision,
          modelId: b.modelId,
          artifactRevision: field == 'artifact' ? 'other' : b.artifactRevision,
          artifactRelativePath: b.artifactRelativePath,
          dimension: field == 'dimension' ? 3 : b.dimension,
          tokenizerId: field == 'tokenizer' ? 'other' : b.tokenizerId,
          poolingId: field == 'pooling' ? 'other' : b.poolingId,
          normalizationId: field == 'normalization'
              ? 'other'
              : b.normalizationId,
        ),
        supportsCancellation: true,
      );
      await expectLater(
        embedder.load(TutorCancellation()),
        failure(RuntimeErrorCode.incompatible),
      );
      expect(embedder.state, EmbeddingRuntimeState.error);
    });
  }
  for (final scenario in [
    'missing-main',
    'duplicate',
    'traversal',
    'invalid-hash',
    'wrong-size',
  ]) {
    test(
      'invalid artifact inventory $scenario fails before native load',
      () async {
        final original = f.config.artifacts.first;
        final files = switch (scenario) {
          'missing-main' => [f.config.artifacts.last],
          'duplicate' => [...f.config.artifacts, original],
          _ => [
            EmbeddingArtifact(
              relativePath: scenario == 'traversal'
                  ? '../outside'
                  : original.relativePath,
              sizeBytes: scenario == 'wrong-size'
                  ? original.sizeBytes + 1
                  : original.sizeBytes,
              sha256: scenario == 'invalid-hash' ? 'invalid' : original.sha256,
            ),
            f.config.artifacts.last,
          ],
        };
        final e = ManagedQueryEmbedder(
          config: SharedEmbeddingConfig(
            binding: rag.binding,
            artifactRoot: f.directory,
            runtimeId: 'TEST_RUNTIME',
            artifacts: files,
          ),
          backend: f.backend,
          operationTimeout: const Duration(seconds: 1),
        );
        try {
          await expectLater(
            e.load(TutorCancellation()),
            failure(RuntimeErrorCode.incompatible),
          );
          expect(f.backend.events, isEmpty);
        } finally {
          await e.whenIdle;
          await e.unload();
        }
      },
    );
  }
  test('timeout returns without releasing a still-running embedder', () async {
    const timeout = Duration(milliseconds: 20);
    final deadlines = <_DeadlineTimer>[];
    await runZoned(
      () async {
        final e = ManagedQueryEmbedder(
          config: f.config,
          backend: f.backend,
          operationTimeout: timeout,
        );
        try {
          await e.load(TutorCancellation());
          expect(deadlines.single.isActive, isFalse);
          f.backend.pending = Completer<List<double>>();
          final timedOut = expectLater(
            e.embed('test', TutorCancellation()),
            failure(RuntimeErrorCode.timeout),
          );
          expect(deadlines.last.isActive, isTrue);
          deadlines.last.fire();
          await timedOut;
          await expectLater(e.unload(), failure(RuntimeErrorCode.busy));
        } finally {
          f.backend.pending?.complete([1, 0]);
          await e.whenIdle;
          await e.unload();
        }
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration != timeout) {
            return parent.createTimer(zone, duration, callback);
          }
          final timer = _DeadlineTimer(callback);
          deadlines.add(timer);
          return timer;
        },
      ),
    );
  });
  test(
    'cancelled partial load cannot issue vectors before explicit recovery',
    () async {
      f.backend.pendingLoad = Completer<EmbeddingCapabilities>();
      final token = TutorCancellation();
      final result = expectLater(
        embedder.load(token),
        failure(RuntimeErrorCode.cancelled),
      );
      for (var i = 0; i < 100 && !f.backend.events.contains('load'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(f.backend.events, contains('load'));
      token.cancel();
      await result;
      await expectLater(embedder.unload(), failure(RuntimeErrorCode.busy));
      f.backend.pendingLoad!.complete(
        EmbeddingCapabilities(
          runtimeId: f.config.runtimeId,
          binding: rag.binding,
          supportsCancellation: true,
        ),
      );
      await embedder.whenIdle;
      expect(embedder.state, EmbeddingRuntimeState.error);
    },
  );
  test('backend exception is a typed embedding operational failure', () async {
    await embedder.load(TutorCancellation());
    f.backend.embedError = StateError('private native detail');
    await expectLater(
      embedder.embed('test', TutorCancellation()),
      failure(RuntimeErrorCode.embeddingFailed),
    );
  });
  test(
    'a pre-registered idle waiter can immediately issue the next embedding',
    () async {
      await embedder.load(TutorCancellation());
      final native = Completer<List<double>>();
      f.backend.pending = native;
      final first = embedder.embed('first', TutorCancellation());
      final next = embedder.whenIdle.then(
        (_) => embedder.embed('second', TutorCancellation()),
      );
      final checked = expectLater(next, completion([1, 0]));
      await Future<void>.delayed(Duration.zero);
      f.backend.pending = null;
      native.complete([1, 0]);
      await first;
      await checked;
    },
  );
  test(
    'idle after load publishes ready before a waiting inference resumes',
    () async {
      final native = Completer<EmbeddingCapabilities>();
      f.backend.pendingLoad = native;
      final loading = embedder.load(TutorCancellation());
      final next = embedder.whenIdle.then(
        (_) => embedder.embed('first', TutorCancellation()),
      );
      final checked = expectLater(next, completion([1, 0]));
      native.complete(
        EmbeddingCapabilities(
          runtimeId: f.config.runtimeId,
          binding: rag.binding,
          supportsCancellation: true,
        ),
      );
      await loading;
      await checked;
    },
  );
  test('idle callback observes settled state synchronously', () async {
    await embedder.load(TutorCancellation());
    final native = Completer<List<double>>();
    f.backend.pending = native;
    final work = embedder.embed('first', TutorCancellation());
    expect(embedder.state, EmbeddingRuntimeState.embedding);
    final observed = embedder.whenIdle.then((_) => embedder.state);
    final checked = expectLater(
      observed,
      completion(EmbeddingRuntimeState.ready),
    );
    native.complete([1, 0]);
    await work;
    await checked;
  });
}
