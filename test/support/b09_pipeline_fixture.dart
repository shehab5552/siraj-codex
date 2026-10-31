import 'dart:async';
import 'dart:io';
import 'package:siraj/integrations/ai/pinned_retriever.dart';
import 'package:siraj/integrations/ai/pipeline_tutor_port.dart';
import 'package:siraj/integrations/ai/rag_runtime_contract.dart';
import 'package:siraj/integrations/ai/runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_pipeline_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';
import 'b09_ai_fixture.dart';

class TestRuntime implements ModelRuntime {
  @override
  ModelRuntimeState state = ModelRuntimeState.ready;
  @override
  ModelConfig? configuration = ModelConfig(
    modelId: 'test',
    modelVersion: 'v1',
    runtimeId: 'test',
    artifactRoot: Directory.systemTemp,
    relativePath: 'test.gguf',
    sha256: 'test-only-not-used-by-real-loader',
    sizeBytes: 24,
    contextLength: 32,
    promptProfileId: 'test-profile',
  );
  @override
  ModelCapabilities? capabilities = const ModelCapabilities(
    runtimeId: 'test',
    contextLength: 32,
    supportsCancellation: true,
  );
  @override
  RuntimeMetrics getMetrics() => const RuntimeMetrics();
  int calls = 0;
  RuntimeFailure? failure;
  Completer<String>? paused;
  @override
  Future<String> generate(GenerationRequest r, TutorCancellation c) async {
    calls++;
    if (failure case final f?) throw f;
    return paused == null ? 'SYNTHETIC TEST ANSWER' : paused!.future;
  }

  @override
  Future<void> get whenIdle async {
    if (paused case final p?) await p.future;
  }

  @override
  Future<void> load(ModelConfig c, TutorCancellation t) async {}
  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> unload() async {}
}

class TestScope implements ScopeResolver {
  ScopeSelection selection = ScopeSelection({'test-pack'});
  final requests = <TutorRequest>[];
  @override
  Future<ScopeSelection> resolve(
    TutorRequest r,
    DatasetRuntimeConfiguration d,
    TutorCancellation c,
  ) async {
    requests.add(r);
    return selection;
  }
}

class TestEvidence implements EvidenceGate {
  EvidenceAssessment assessment = EvidenceAssessment(
    decision: EvidenceDecision.full,
    approvedSources: [ref],
  );
  final received = <List<RetrievedChunk>>[];
  @override
  Future<EvidenceAssessment> evaluate(
    TutorRequest r,
    List<RetrievedChunk> chunks,
    TutorCancellation c,
  ) async {
    received.add(chunks);
    return assessment;
  }
}

class TestPrompts implements TutorPromptBuilder {
  int calls = 0;
  Completer<GenerationRequest>? paused;
  final received = <List<ResolvedSource>>[];
  @override
  Future<GenerationRequest> prepare(
    TutorRequest r,
    List<ResolvedSource> chunks,
    EvidenceAssessment e,
    ModelConfig m,
    TutorCancellation c,
  ) async {
    calls++;
    received.add(chunks);
    if (paused != null) return paused!.future;
    return GenerationRequest(
      requestId: r.requestId,
      prompt: 'TEST ONLY',
      promptTokens: 2,
      maxTokens: 4,
    );
  }
}

class TestAnswers implements AnswerValidator {
  TutorResult? result;
  @override
  Future<TutorResult> validate(
    TutorRequest r,
    String text,
    List<ResolvedSource> chunks,
    EvidenceAssessment e,
    TutorCancellation c,
  ) async =>
      result ??
      TutorResult.answer(
        text,
        e.approvedSources,
        partial: e.decision == EvidenceDecision.partialIndependent,
      );
}

class PipelineFixture {
  final datasets = TestDatasets();
  final runtime = TestRuntime();
  final scope = TestScope();
  final evidence = TestEvidence();
  final prompts = TestPrompts();
  final answers = TestAnswers();
  late final pipeline = PipelineTutorPort(
    datasets: datasets,
    runtime: runtime,
    retriever: const PinnedRetriever(topK: 5),
    scope: scope,
    evidence: evidence,
    prompts: prompts,
    answers: answers,
    requestTimeout: const Duration(seconds: 1),
  );
  TutorRequest request({
    String id = 'request',
    String revision = 'fixture-r1',
    TutorCancellation? cancel,
    List<TutorContextMessage> history = const [],
  }) => TutorRequest(
    requestId: id,
    userId: 'test-user',
    accountEpoch: 'test-epoch',
    conversationId: 'test-chat',
    question: 'SYNTHETIC QUESTION',
    datasetRevision: revision,
    cancellation: cancel ?? TutorCancellation(),
    history: history,
  );
}
