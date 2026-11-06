package com.example.siraj.ai_runtime;

/** Sanitized public failure; never includes a prompt, model path or native trace. */
public final class RuntimeFailure extends RuntimeException {
  public enum Code {
    dependencyMissing, dependencyIncompatible, jniMissing, unsupportedAbi,
    resourceUnavailable, unsafeResourcePath, integrityFailure, formatRejected,
    initializationFailed, busy, notInitialized, disposed, cancelled,
    invalidRequest, embeddingDimension, nonFiniteEmbedding, zeroEmbedding,
    generationFailed, unsupportedContent
  }

  public final Code code;

  public RuntimeFailure(Code code) {
    super(code.name());
    this.code = code;
  }
}
