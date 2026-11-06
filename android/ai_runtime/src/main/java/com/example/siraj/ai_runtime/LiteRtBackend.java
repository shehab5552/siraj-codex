package com.example.siraj.ai_runtime;

import com.google.ai.edge.litertlm.*;
import java.io.File;
import java.util.Collections;

/** Real SDK0.19.0 adapter. No scientific defaults or fake answers. */
public final class LiteRtBackend implements RuntimeBackend {
  private final boolean benchmarkEnabled;
  public LiteRtBackend(boolean benchmarkEnabled) { this.benchmarkEnabled=benchmarkEnabled; }
  private static void privateLogging() {
    // Official Engine.kt LogSeverity.INFINITY(1000): suppress native logs that
    // could contain token/prompt snippets, including native exception text.
    Engine.Companion.setNativeMinLogSeverity(LogSeverity.INFINITY);
  }
  @Override public Llm loadLlm(File path) {
    privateLogging();
    ExperimentalFlags.INSTANCE.setEnableBenchmark(benchmarkEnabled);
    Engine engine=new Engine(new EngineConfig(path.getAbsolutePath(),new Backend.CPU()));
    try { engine.initialize(); }
    catch(Throwable error) {
      if(engine.isInitialized()) {try {engine.close();}catch(Throwable ignored) {}}
      throw RuntimeManager.sanitized(error,RuntimeFailure.Code.initializationFailed);
    }
    return new Llm() {
      public RuntimeBackend.Conversation conversation(String system) {
        // No tools are registered: disable SDK automatic tool execution so
        // unexpected tool calls reach our explicit unsupported-content gate.
        com.google.ai.edge.litertlm.Conversation c=engine.createConversation(
            new ConversationConfig(Contents.Companion.of(system),Collections.emptyList(),Collections.emptyList(),null,false));
        return new RuntimeBackend.Conversation() {
          public void start(String input,RuntimeBackend.Callback callback) {
            c.sendMessageAsync(input,new MessageCallback() {
              private RuntimeFailure.Code rejected;
              public void onMessage(Message message) {
                if(rejected!=null)return;
                StringBuilder text=new StringBuilder();
                if(!message.getToolCalls().isEmpty()) { rejected=RuntimeFailure.Code.unsupportedContent;c.cancelProcess();return; }
                for(Content content:message.getContents().getContents()) {
                  if(content instanceof Content.Text t)text.append(t.getText());
                  else { rejected=RuntimeFailure.Code.unsupportedContent;c.cancelProcess();return; }
                }
                // Official callbacks contain message deltas; channels such as
                // reasoning are intentionally never emitted as answer text.
                if(text.length()>0)callback.chunk(text.toString());
              }
              public void onDone() { if(rejected!=null)callback.failed(rejected);else callback.done(); }
              public void onError(Throwable ignored) { callback.failed(rejected!=null?rejected:RuntimeFailure.Code.generationFailed); }
            },Collections.emptyMap(),null,null,null,256);
          }
          public void cancel() { c.cancelProcess(); }
          public RuntimeMetrics metrics() {
            if(!benchmarkEnabled)return null;
            BenchmarkInfo b=c.getBenchmarkInfo();
            return new RuntimeMetrics(b.getInitTimeInSecond(),b.getTimeToFirstTokenInSecond(),b.getLastPrefillTokenCount(),b.getLastDecodeTokenCount(),b.getLastPrefillTokensPerSecond(),b.getLastDecodeTokensPerSecond());
          }
          public void close() { c.close(); }
        };
      }
      public void close() { engine.close(); }
    };
  }
  @Override public Embedding loadEmbedding(File path) {
    privateLogging();
    EmbeddingEngine engine=new EmbeddingEngine(new EmbeddingEngineConfig(path.getAbsolutePath(),new Backend.CPU()));
    try { engine.initialize(); }
    catch(Throwable error) {
      if(engine.isInitialized()) {try {engine.close();}catch(Throwable ignored) {}}
      throw RuntimeManager.sanitized(error,RuntimeFailure.Code.initializationFailed);
    }
    return new Embedding() {
      public float[] embed(String input) {
        // Nullable SDK defaults are only engineering defaults. They do not
        // establish Dataset prefix/normalization/pooling/tokenizer parity.
        return engine.computeEmbedding(Collections.singletonList(new InputData.Text(input)),new EmbeddingOptions()).getEmbedding();
      }
      public void close() { engine.close(); }
    };
  }
}
