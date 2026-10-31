import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/integrations/ai/pipeline_tutor_port.dart';
import 'package:siraj/integrations/ai/pinned_retriever.dart';
import 'package:siraj/integrations/ai/runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_pipeline_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';
import 'support/b09_ai_fixture.dart';
import 'support/b09_pipeline_fixture.dart';

Future<void> embeddingStarted(PipelineFixture f) async {
  for (var i = 0; i < 100 && f.datasets.handle.embedder.calls == 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(f.datasets.handle.embedder.calls, 1);
}

void main() {
  late PipelineFixture f;
  setUp(() {
    f = PipelineFixture();
  });
  test(
    'adapter produces checked B08 reply from approved retrieval only',
    () async {
      final q = f.request();
      final reply = await f.pipeline.ask(q);
      expect(reply.checkedFor(q).status, TutorStatus.answer);
      expect(reply.result.sources, [ref]);
      expect(f.prompts.received.single.single.snippet, 'synthetic test text');
      expect(f.datasets.handle.closed, 1);
    },
  );
  test(
    'missing runtime reports typed unavailable without opening dataset',
    () async {
      f.runtime.state = ModelRuntimeState.notLoaded;
      expect(f.pipeline.availability.isReady, false);
      final reply = await f.pipeline.ask(f.request());
      expect(reply.result.error, TutorErrorCode.resourceNotReady);
      expect(f.datasets.opened, isEmpty);
    },
  );
  test(
    'follow-up performs fresh retrieval and passes context only to policy ports',
    () async {
      await f.pipeline.ask(f.request());
      await f.pipeline.ask(
        f.request(
          id: 'follow-up',
          history: [
            const TutorContextMessage(
              role: 'ASSISTANT',
              text: 'OLD TEXT IS NOT EVIDENCE',
            ),
          ],
        ),
      );
      expect(f.datasets.handle.embedder.calls, 2);
      expect(
        f.scope.requests.last.history.single.text,
        'OLD TEXT IS NOT EVIDENCE',
      );
      expect(f.evidence.received.last.single.snippet, 'synthetic test text');
    },
  );
  test('ambiguous scope refuses without retrieval or generation', () async {
    f.scope.selection = ScopeSelection({});
    final r = await f.pipeline.ask(f.request());
    expect(r.result.reason, TutorReason.needsScopeClarification);
    expect(f.runtime.calls, 0);
    expect(f.datasets.handle.embedder.calls, 0);
  });
  for (final d in [EvidenceDecision.insufficient, EvidenceDecision.ambiguous]) {
    test('$d refuses before model', () async {
      f.evidence.assessment = EvidenceAssessment(decision: d);
      final r = await f.pipeline.ask(f.request());
      expect(r.result.status, TutorStatus.refusal);
      expect(r.result.sources, isEmpty);
      expect(f.runtime.calls, 0);
    });
  }
  test('independent partial remains partial after output validation', () async {
    f.evidence.assessment = EvidenceAssessment(
      decision: EvidenceDecision.partialIndependent,
      approvedSources: [ref],
      supportedSubparts: ['supported'],
      unsupportedSubparts: ['unsupported'],
    );
    final r = await f.pipeline.ask(f.request());
    expect(r.result.isPartial, true);
  });
  test('validator cannot upgrade partial evidence into full answer', () async {
    f.evidence.assessment = EvidenceAssessment(
      decision: EvidenceDecision.partialIndependent,
      approvedSources: [ref],
      supportedSubparts: ['supported'],
      unsupportedSubparts: ['unsupported'],
    );
    f.answers.result = TutorResult.answer('test', [ref]);
    final r = await f.pipeline.ask(f.request());
    expect(r.result.error, TutorErrorCode.invalidResponse);
  });
  test('gate cannot approve a source outside retrieved set', () async {
    f.evidence.assessment = EvidenceAssessment(
      decision: EvidenceDecision.full,
      approvedSources: [
        const SourceReference(
          packId: 'test-pack',
          chunkId: 'invented',
          datasetRevision: 'fixture-r1',
        ),
      ],
    );
    final r = await f.pipeline.ask(f.request());
    expect(r.result.error, TutorErrorCode.invalidResponse);
    expect(f.runtime.calls, 0);
  });
  test('post validator cannot smuggle model-created sources', () async {
    f.answers.result = TutorResult.answer('test', [
      const SourceReference(
        packId: 'test-pack',
        chunkId: 'invented',
        datasetRevision: 'fixture-r1',
      ),
    ]);
    final r = await f.pipeline.ask(f.request());
    expect(r.result.error, TutorErrorCode.invalidResponse);
  });
  test('runtime OOM is operational error, never a knowledge refusal', () async {
    f.runtime.failure = const RuntimeFailure(RuntimeErrorCode.outOfMemory);
    final r = await f.pipeline.ask(f.request());
    expect(r.result.error, TutorErrorCode.outOfMemory);
    expect(r.result.status, TutorStatus.error);
    expect(f.datasets.handle.closed, 1);
  });
  test(
    'cancel during embedding retains lease until pending work drains',
    () async {
      final pause = Completer<List<double>>();
      f.datasets.handle.embedder.paused = pause;
      final token = TutorCancellation();
      final reply = f.pipeline.ask(f.request(cancel: token));
      await embeddingStarted(f);
      await f.pipeline.cancel('request');
      expect((await reply).result.error, TutorErrorCode.requestCancelled);
      expect(f.datasets.handle.closed, 0);
      expect(
        (await f.pipeline.ask(f.request(id: 'new'))).result.status,
        TutorStatus.error,
      );
      pause.complete([1, 0]);
      await f.pipeline.whenIdle;
      expect(f.datasets.handle.closed, 1);
      expect(f.runtime.calls, 0);
    },
  );
  test(
    'dataset swap does not change a request already holding its lease',
    () async {
      final pause = Completer<List<double>>();
      f.datasets.handle.embedder.paused = pause;
      final pending = f.pipeline.ask(f.request());
      await embeddingStarted(f);
      f.datasets.availableRevision = 'fixture-r2';
      pause.complete([1, 0]);
      final r = await pending;
      expect(r.result.status, TutorStatus.answer);
      expect(r.result.sources.single.datasetRevision, 'fixture-r1');
    },
  );
  test(
    'source resolver opens exact historical revision without runtime',
    () async {
      f.runtime.state = ModelRuntimeState.notLoaded;
      expect((await f.pipeline.resolve(ref))?.reference, ref);
      expect(
        await f.pipeline.resolve(
          const SourceReference(
            packId: 'test-pack',
            chunkId: 'test-chunk',
            datasetRevision: 'missing',
          ),
        ),
        null,
      );
      expect(f.datasets.opened, ['fixture-r1', 'missing']);
    },
  );
  test('mismatched source metadata is unavailable', () async {
    f.datasets.handle.resolver = (_) => const ResolvedSource(
      reference: SourceReference(
        packId: 'test-pack',
        chunkId: 'new',
        datasetRevision: 'fixture-r2',
      ),
      snippet: 'wrong',
    );
    expect(await f.pipeline.resolve(ref), null);
  });
  test('closed adapter never starts another request', () async {
    await f.pipeline.close();
    expect(f.pipeline.availability.isReady, false);
    expect(
      (await f.pipeline.ask(f.request())).result.error,
      TutorErrorCode.resourceNotReady,
    );
  });
  test(
    'request timeout retains a pending retrieval lease until drainage',
    () async {
      final service = PipelineTutorPort(
        datasets: f.datasets,
        runtime: f.runtime,
        retriever: const PinnedRetriever(topK: 5),
        scope: f.scope,
        evidence: f.evidence,
        prompts: f.prompts,
        answers: f.answers,
        requestTimeout: const Duration(milliseconds: 80),
      );
      final pause = Completer<List<double>>();
      f.datasets.handle.embedder.paused = pause;
      final pending = service.ask(f.request());
      await embeddingStarted(f);
      expect((await pending).result.error, TutorErrorCode.generationFailed);
      expect(f.datasets.handle.closed, 0);
      pause.complete([1, 0]);
      await service.whenIdle;
      expect(f.datasets.handle.closed, 1);
    },
  );
  test(
    'runtime configuration swap while preparing prompt never generates',
    () async {
      f.prompts.paused = Completer<GenerationRequest>();
      final pending = f.pipeline.ask(f.request());
      for (var i = 0; i < 100 && f.prompts.calls == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(f.prompts.calls, 1);
      final old = f.runtime.configuration!;
      f.runtime.configuration = ModelConfig(
        modelId: 'different',
        modelVersion: old.modelVersion,
        runtimeId: old.runtimeId,
        artifactRoot: old.artifactRoot,
        relativePath: old.relativePath,
        sha256: old.sha256,
        sizeBytes: old.sizeBytes,
        contextLength: old.contextLength,
        promptProfileId: 'different',
      );
      f.prompts.paused!.complete(
        const GenerationRequest(
          requestId: 'request',
          prompt: 'TEST',
          promptTokens: 2,
          maxTokens: 4,
        ),
      );
      expect((await pending).result.error, TutorErrorCode.resourceNotReady);
      expect(f.runtime.calls, 0);
    },
  );
  test('unrelated cancel does not cancel current request', () async {
    f.datasets.handle.embedder.paused = Completer<List<double>>();
    final pending = f.pipeline.ask(f.request());
    await embeddingStarted(f);
    await f.pipeline.cancel('unrelated');
    f.datasets.handle.embedder.paused!.complete([1, 0]);
    expect((await pending).result.status, TutorStatus.answer);
  });
  test(
    'partial decision without independent unsupported requirements is invalid',
    () async {
      f.evidence.assessment = EvidenceAssessment(
        decision: EvidenceDecision.partialIndependent,
        approvedSources: [ref],
        supportedSubparts: ['one'],
      );
      expect(
        (await f.pipeline.ask(f.request())).result.error,
        TutorErrorCode.invalidResponse,
      );
      expect(f.runtime.calls, 0);
    },
  );
  test(
    'close retains historical source lease until its pending read drains',
    () async {
      final pause = Completer<ResolvedSource?>();
      f.datasets.handle.resolver = (_) => pause.future;
      final source = f.pipeline.resolve(ref);
      for (var i = 0; i < 100 && f.datasets.opened.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await Future<void>.delayed(Duration.zero);
      var closed = false;
      final closing = f.pipeline.close().then((_) {
        closed = true;
      });
      try {
        await Future<void>.delayed(Duration.zero);
        expect(closed, false);
        expect(f.datasets.handle.closed, 0);
      } finally {
        pause.complete(const ResolvedSource(reference: ref, snippet: 'test'));
        expect(await source, null);
        await closing;
      }
      expect(f.datasets.handle.closed, 1);
    },
  );
}
