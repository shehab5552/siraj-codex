import 'dart:async';

enum AiRuntimeErrorCode {
  dependencyMissing,
  dependencyIncompatible,
  jniMissing,
  unsupportedAbi,
  resourceUnavailable,
  unsafeResourcePath,
  integrityFailure,
  formatRejected,
  initializationFailed,
  busy,
  notInitialized,
  disposed,
  cancelled,
  invalidRequest,
  embeddingDimension,
  nonFiniteEmbedding,
  zeroEmbedding,
  generationFailed,
  unsupportedContent,
  channelUnavailable,
  protocolViolation,
}

class AiRuntimeFailure implements Exception {
  const AiRuntimeFailure(this.code);
  final AiRuntimeErrorCode code;
  @override
  String toString() => 'AiRuntimeFailure(${code.name})';
}

enum AiGenerationEventType { started, chunk, completed, failed, cancelled }

class AiGenerationEvent {
  const AiGenerationEvent(this.type, {this.text, this.error});
  final AiGenerationEventType type;
  final String? text;
  final AiRuntimeErrorCode? error;
}

class AiGeneration {
  const AiGeneration(this.requestId, this.events, this.cancel);
  final String requestId;
  final Stream<AiGenerationEvent> events;
  final Future<void> Function() cancel;
}

class AiRuntimeStatus {
  const AiRuntimeStatus({
    required this.version,
    required this.abi,
    required this.jniLoaded,
    required this.llmLoaded,
    required this.embeddingLoaded,
  });
  final String version, abi;
  final bool jniLoaded, llmLoaded, embeddingLoaded;
}

class AiEmbedding {
  AiEmbedding(List<double> values, this.elapsedMs)
    : values = List.unmodifiable(values);
  final List<double> values;
  final double elapsedMs;
}

abstract interface class AiRuntimeClient {
  Future<AiRuntimeStatus> status();
  Future<void> initializeLlm(String resourceId);
  Future<void> initializeEmbedding(String resourceId);
  Future<AiGeneration> generate({
    required String systemInstruction,
    required String input,
  });
  Future<AiEmbedding> embed(String input);
  Future<void> closeLlm();
  Future<void> closeEmbedding();
  Future<void> dispose();
}
