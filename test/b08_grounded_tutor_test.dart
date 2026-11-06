import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/ai_runtime/ai_runtime_client.dart';
import 'package:siraj/features/chat/grounded_tutor_service.dart';
import 'package:siraj/features/chat/tutor_contracts.dart';

class TestRuntime implements AiRuntimeClient {
  final output = StreamController<AiGenerationEvent>();
  int calls = 0, cancels = 0;
  @override
  Future<AiGeneration> generate({
    required String systemInstruction,
    required String input,
  }) async {
    calls++;
    return AiGeneration('test', output.stream, () async {
      cancels++;
      output.add(const AiGenerationEvent(AiGenerationEventType.cancelled));
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unused test port');
}

class TestEvidence implements TutorEvidencePort {
  bool current = true, valid = true, noEvidence = false;
  final source = SourceReference(
    packId: 'test-pack',
    chunkId: 'test-chunk',
    datasetRevision: 'test-revision',
  );
  @override
  Future<GroundedContext?> prepare(String q, TutorCancellation c) async =>
      noEvidence
      ? null
      : GroundedContext(
          systemInstruction: 'test-only instruction',
          prompt: 'test-only evidence',
          sources: [source],
          revision: 'test-revision',
        );
  @override
  Future<bool> validateAnswer(GroundedContext c, String answer) async => valid;
  @override
  bool isRevisionCurrent(String revision) =>
      current && revision == 'test-revision';
}

void main() {
  late TestRuntime runtime;
  late TestEvidence evidence;
  setUp(() {
    runtime = TestRuntime();
    evidence = TestEvidence();
  });
  tearDown(() async {
    if (runtime.calls == 0) runtime.output.stream.listen((_) {});
    await runtime.output.close();
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test(
    'missing scientific authority does not call runtime or invent refusal',
    () async {
      final result = await GroundedTutorService(
        runtime: runtime,
      ).ask('question', TutorCancellation());
      expect(result.reason, TutorReason.resourcesUnavailable);
      expect(runtime.calls, 0);
    },
  );
  test('no evidence refuses before generation', () async {
    evidence.noEvidence = true;
    final r = await GroundedTutorService(
      runtime: runtime,
      evidence: evidence,
    ).ask('question', TutorCancellation());
    expect(r.status, TutorStatus.refusal);
    expect(runtime.calls, 0);
  });
  test('valid source-revision and postcheck required before answer', () async {
    final f = GroundedTutorService(
      runtime: runtime,
      evidence: evidence,
    ).ask('question', TutorCancellation());
    await flush();
    runtime.output.add(
      const AiGenerationEvent(
        AiGenerationEventType.chunk,
        text: 'test contract answer',
      ),
    );
    runtime.output.add(
      const AiGenerationEvent(AiGenerationEventType.completed),
    );
    unawaited(runtime.output.close());
    final r = await f;
    expect(r.status, TutorStatus.answer);
    expect(r.sources.single.chunkId, 'test-chunk');
  });
  test('revision change during generation rejects result', () async {
    final f = GroundedTutorService(
      runtime: runtime,
      evidence: evidence,
    ).ask('question', TutorCancellation());
    await flush();
    evidence.current = false;
    runtime.output.add(
      const AiGenerationEvent(AiGenerationEventType.chunk, text: 'test'),
    );
    runtime.output.add(
      const AiGenerationEvent(AiGenerationEventType.completed),
    );
    unawaited(runtime.output.close());
    expect((await f).reason, TutorReason.sourceUnavailable);
  });
  test('failed postcheck rejects all text', () async {
    evidence.valid = false;
    final f = GroundedTutorService(
      runtime: runtime,
      evidence: evidence,
    ).ask('question', TutorCancellation());
    await flush();
    runtime.output.add(
      const AiGenerationEvent(AiGenerationEventType.chunk, text: 'unverified'),
    );
    runtime.output.add(
      const AiGenerationEvent(AiGenerationEventType.completed),
    );
    unawaited(runtime.output.close());
    expect((await f).status, isNot(TutorStatus.answer));
  });
  test('cancellation does not return text as an answer', () async {
    final token = TutorCancellation();
    final f = GroundedTutorService(
      runtime: runtime,
      evidence: evidence,
    ).ask('question', token);
    await flush();
    token.cancel();
    expect((await f).reason, TutorReason.cancelled);
    expect(runtime.cancels, 1);
  });
  test('reference shape and mixed revisions rejected', () {
    expect(
      () => SourceReference(packId: '', chunkId: 'c', datasetRevision: 'r'),
      throwsArgumentError,
    );
    expect(
      () => TutorResult.answer('x', [
        evidence.source,
        SourceReference(packId: 'p', chunkId: 'c', datasetRevision: 'other'),
      ]),
      throwsArgumentError,
    );
  });
}
