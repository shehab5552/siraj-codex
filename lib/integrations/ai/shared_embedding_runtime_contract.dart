import 'dart:io';
import 'rag_runtime_contract.dart';
import 'runtime_contract.dart';
import 'tutor_contract.dart';

enum EmbeddingRuntimeState { notLoaded, loading, ready, embedding, error }

class EmbeddingArtifact {
  const EmbeddingArtifact({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
  });
  final String relativePath, sha256;
  final int sizeBytes;
}

/// Runtime configuration, not a new on-disk manifest. The approved resolver
/// supplies every model/tokenizer/config file, exact hashes and binding.
class SharedEmbeddingConfig {
  SharedEmbeddingConfig({
    required this.binding,
    required this.artifactRoot,
    required this.runtimeId,
    required Iterable<EmbeddingArtifact> artifacts,
  }) : artifacts = List.unmodifiable(artifacts);
  final EmbeddingBinding binding;

  /// Caller owns an immutable revision lease until unload succeeds.
  final Directory artifactRoot;
  final String runtimeId;
  final List<EmbeddingArtifact> artifacts;
}

class EmbeddingCapabilities {
  const EmbeddingCapabilities({
    required this.runtimeId,
    required this.binding,
    required this.supportsCancellation,
  });
  final String runtimeId;
  final EmbeddingBinding binding;
  final bool supportsCancellation;
}

class EmbeddingRequest {
  const EmbeddingRequest({required this.requestId, required this.text});
  final String requestId, text;
}

/// Native/FFI selection and approved preprocessing belong to the actual adapter.
/// No HTTP or automatic normalization/tokenizer substitution is permitted.
abstract interface class EmbeddingBackend {
  Future<EmbeddingCapabilities> load(
    SharedEmbeddingConfig config,
    TutorCancellation cancellation,
  );
  Future<List<double>> embed(
    EmbeddingRequest request,
    TutorCancellation cancellation,
  );
  Future<void> cancel(String requestId);
  Future<void> unload();
}

class UnavailableEmbeddingBackend implements EmbeddingBackend {
  const UnavailableEmbeddingBackend();
  @override
  Future<EmbeddingCapabilities> load(
    SharedEmbeddingConfig config,
    TutorCancellation cancellation,
  ) async => throw const RuntimeFailure(RuntimeErrorCode.notReady);
  @override
  Future<List<double>> embed(
    EmbeddingRequest request,
    TutorCancellation cancellation,
  ) async => throw const RuntimeFailure(RuntimeErrorCode.notReady);
  @override
  Future<void> cancel(String requestId) async {}
  @override
  Future<void> unload() async {}
}
