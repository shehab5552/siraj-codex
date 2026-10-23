import 'dart:io';
import 'tutor_contract.dart';

enum ModelRuntimeState { notLoaded, loading, ready, generating, error }

enum RuntimeErrorCode {
  notReady,
  incompatible,
  loadFailed,
  generationFailed,
  embeddingFailed,
  cancelled,
  busy,
  outOfMemory,
  invalidOutput,
  timeout,
}

class RuntimeFailure implements Exception {
  const RuntimeFailure(this.code);
  final RuntimeErrorCode code;
}

class ModelConfig {
  const ModelConfig({
    required this.modelId,
    required this.modelVersion,
    required this.runtimeId,
    required this.artifactRoot,
    required this.relativePath,
    required this.sha256,
    required this.sizeBytes,
    required this.contextLength,
    required this.promptProfileId,
  });
  final String modelId,
      modelVersion,
      runtimeId,
      relativePath,
      sha256,
      promptProfileId;

  /// Must belong to an immutable app-private model lease retained until unload.
  final Directory artifactRoot;
  final int sizeBytes, contextLength;
}

class ModelCapabilities {
  const ModelCapabilities({
    required this.runtimeId,
    required this.contextLength,
    required this.supportsCancellation,
  });
  final String runtimeId;
  final int contextLength;
  final bool supportsCancellation;
  // No streaming adapter is enabled before Android TC20 acceptance.
}

class GenerationRequest {
  const GenerationRequest({
    required this.requestId,
    required this.prompt,
    required this.promptTokens,
    required this.maxTokens,
  });
  final String requestId, prompt;

  /// Supplied by the approved prompt/tokenizer adapter, never a character count.
  final int promptTokens, maxTokens;
}

abstract interface class ModelBackend {
  Future<ModelCapabilities> load(
    ModelConfig config,
    TutorCancellation cancellation,
  );
  Future<String> generate(
    GenerationRequest request,
    TutorCancellation cancellation,
  );
  Future<void> cancel(String requestId);
  Future<void> unload();
}

/// Last successful wall times. Load includes integrity/preflight; optional native
/// measurements remain absent until an adapter actually measures them.
class RuntimeMetrics {
  const RuntimeMetrics({
    this.loadMs,
    this.completionMs,
    this.firstTokenMs,
    this.peakRamBytes,
  });
  final int? loadMs, completionMs, firstTokenMs, peakRamBytes;
}

abstract interface class ModelRuntime {
  ModelRuntimeState get state;

  /// Stable immutable configuration object for the entire loaded lifecycle.
  ModelConfig? get configuration;
  ModelCapabilities? get capabilities;

  /// Completes only after actual backend and cancel drainage, including errors.
  Future<void> get whenIdle;
  RuntimeMetrics getMetrics();
  Future<void> load(ModelConfig config, TutorCancellation cancellation);
  Future<String> generate(
    GenerationRequest request,
    TutorCancellation cancellation,
  );
  Future<void> cancel(String requestId);
  Future<void> unload();
}
