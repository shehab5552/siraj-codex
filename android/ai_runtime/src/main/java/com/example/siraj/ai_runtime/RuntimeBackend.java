package com.example.siraj.ai_runtime;

import java.io.File;

/** Narrow Java port; SDK types and model paths never cross the Flutter API. */
public interface RuntimeBackend {
  interface Callback {
    void chunk(String text);
    void done();
    void failed(RuntimeFailure.Code code);
  }
  interface Conversation extends AutoCloseable {
    void start(String input, Callback callback);
    void cancel();
    void close();
  }
  interface Llm extends AutoCloseable {
    Conversation conversation(String systemInstruction);
    void close();
  }
  interface Embedding extends AutoCloseable {
    float[] embed(String input);
    void close();
  }
  Llm loadLlm(File verifiedPath);
  Embedding loadEmbedding(File verifiedPath);
}
