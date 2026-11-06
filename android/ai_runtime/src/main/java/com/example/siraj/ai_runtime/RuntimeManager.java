package com.example.siraj.ai_runtime;

import java.io.File;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Supplier;

/** Worker owns all handles. Native callbacks enqueue ordered work; close waits
 * for a native terminal callback, never destroys a still-running conversation.
 * No blocking work or future.get() runs on Android's main thread. */
public final class RuntimeManager {
  public interface Resolver { File resolve(String id, boolean embedding); }
  public interface Events { void event(String id, String type, int sequence, String text, String code, RuntimeMetrics metrics); }
  private final RuntimeBackend backend;
  private final Resolver resolver;
  private final Events events;
  private final ExecutorService worker=Executors.newSingleThreadExecutor(r->new Thread(r,"siraj-ai-worker"));
  private final Set<String> usedIds=new HashSet<>();
  private volatile RuntimeBackend.Llm llm;
  private volatile RuntimeBackend.Embedding embedding;
  private volatile boolean embeddingQuarantined;
  // Process ownership survives Activity recreation and missing terminal events.
  // SDK0.19.0 embedding close is not transactional/idempotent: a failed-close
  // embedding owner stays retained until process exit, without retrying delete.
  private static final Object RUNTIME_LIFECYCLE=new Object();
  private static RuntimeManager processOwner;
  private volatile boolean disposed;
  private Request active;
  private CompletableFuture<Void> closingLlm;
  private RuntimeFailure.Code closeFailure;
  private CompletableFuture<Void> disposal;
  private static final class Request {
    final String id; final AtomicBoolean terminal=new AtomicBoolean();
    RuntimeBackend.Conversation conversation; boolean cancelRequested; int sequence;
    RuntimeFailure.Code cancelFailure;
    int characters; boolean hasNonBlankText; RuntimeFailure.Code failure;
    Request(String id) { this.id=id; }
  }
  public RuntimeManager(RuntimeBackend backend,Resolver resolver,Events events) {
    this.backend=Objects.requireNonNull(backend);this.resolver=Objects.requireNonNull(resolver);this.events=Objects.requireNonNull(events);
  }
  private static <T> CompletableFuture<T> failed(Throwable error) { CompletableFuture<T> f=new CompletableFuture<>();f.completeExceptionally(error);return f; }
  private <T> CompletableFuture<T> submit(Supplier<T> task) {
    if(disposed)return failed(new RuntimeFailure(RuntimeFailure.Code.disposed));
    return queue(task);
  }
  private <T> CompletableFuture<T> queue(Supplier<T> task) {
    CompletableFuture<T> f=new CompletableFuture<>();
    try { worker.execute(()-> { try { f.complete(task.get()); }
      catch(Throwable e) { f.completeExceptionally(sanitized(e,RuntimeFailure.Code.generationFailed)); } }); }
    catch(RejectedExecutionException e) { f.completeExceptionally(new RuntimeFailure(RuntimeFailure.Code.disposed)); }
    return f;
  }
  static RuntimeFailure sanitized(Throwable e,RuntimeFailure.Code fallback) {
    if(e instanceof RuntimeFailure f)return f;
    if(e instanceof NoClassDefFoundError)return new RuntimeFailure(RuntimeFailure.Code.dependencyMissing);
    if(e instanceof UnsatisfiedLinkError)return new RuntimeFailure(RuntimeFailure.Code.jniMissing);
    if(e instanceof LinkageError)return new RuntimeFailure(RuntimeFailure.Code.dependencyIncompatible);
    return new RuntimeFailure(fallback);
  }
  public CompletableFuture<Void> initialize(String id,boolean isEmbedding) {
    return submit(()-> {
      if(disposed)throw new RuntimeFailure(RuntimeFailure.Code.disposed);
      synchronized(RUNTIME_LIFECYCLE) {
        if(processOwner!=null && processOwner.embeddingQuarantined)throw new RuntimeFailure(RuntimeFailure.Code.embeddingCloseFailed);
        if(processOwner!=null && processOwner!=this)throw new RuntimeFailure(RuntimeFailure.Code.busy);
        // Co-residency is deliberately closed until physical-device memory evidence.
        if(llm!=null || embedding!=null || active!=null || closingLlm!=null)throw new RuntimeFailure(RuntimeFailure.Code.busy);
        File path=resolver.resolve(id,isEmbedding);
        processOwner=this;
        try {
          if(isEmbedding)embedding=backend.loadEmbedding(path);else llm=backend.loadLlm(path);
        } catch(Throwable e) { releaseProcessOwner();throw sanitized(e,RuntimeFailure.Code.initializationFailed); }
        if(disposed) { closeIdle();throw new RuntimeFailure(RuntimeFailure.Code.disposed); }
        return null;
      }
    });
  }
  public CompletableFuture<Void> generate(String id,String system,String input) {
    return submit(()-> {
      if(disposed)throw new RuntimeFailure(RuntimeFailure.Code.disposed);
      if(llm==null)throw new RuntimeFailure(RuntimeFailure.Code.notInitialized);
      if(active!=null || closingLlm!=null)throw new RuntimeFailure(RuntimeFailure.Code.busy);
      validateText(input);validateText(system);
      if(id==null || !id.matches("[A-Za-z0-9_-]{1,128}") || usedIds.size()>=4096 || !usedIds.add(id))throw new RuntimeFailure(RuntimeFailure.Code.invalidRequest);
      Request request=new Request(id);active=request;
      emit(request,"generationStarted",null,null);
      try {
        request.conversation=llm.conversation(system);
        request.conversation.start(input,new RuntimeBackend.Callback() {
          public void chunk(String text) {
            if(request.terminal.get())return;
            queue(()-> {
              // In-flight text remains valid until Native terminates. A cancel
              // can race normal completion; dropping its suffix fabricates a
              // truncated completed answer. Tutor separately guards abandoned turns.
              if(active!=request || request.failure!=null)return null;
              if(text==null || request.characters+text.length()>262144) {
                request.failure=RuntimeFailure.Code.generationFailed;request.conversation.cancel();return null;
              }
              request.characters+=text.length();request.hasNonBlankText|=!text.trim().isEmpty();emit(request,"generationChunk",text,null);return null;
            });
          }
          public void done() { terminal(null); }
          public void failed(RuntimeFailure.Code code) { terminal(code); }
          private void terminal(RuntimeFailure.Code code) {
            if(request.terminal.compareAndSet(false,true))queue(()-> { finish(request,code);return null; });
          }
        });
      } catch(Throwable e) {
        if(request.terminal.compareAndSet(false,true))finish(request,sanitized(e,RuntimeFailure.Code.generationFailed).code);
      }
      return null;
    });
  }
  private void emit(Request r,String type,String text,String code) { emit(r,type,text,code,null); }
  private void emit(Request r,String type,String text,String code,RuntimeMetrics metrics) {
    try { events.event(r.id,type,r.sequence++,text,code,metrics); }
    catch(RuntimeException ignored) { /* Detached listener cannot leak native handles. */ }
  }
  private void finish(Request r,RuntimeFailure.Code code) {
    if(active!=r)return;
    RuntimeMetrics metrics=null;
    if(r.conversation!=null) {
      if(r.failure==null && code==null && r.hasNonBlankText) {
        try { metrics=r.conversation.metrics(); }
        catch(Throwable ignored) { /* Optional benchmark unavailable; no invented values. */ }
      }
      try { r.conversation.close(); }
      catch(Throwable e) { code=sanitized(e,RuntimeFailure.Code.generationFailed).code; }
    }
    active=null;
    RuntimeFailure.Code failure=r.failure!=null?r.failure:code;
    if(failure==RuntimeFailure.Code.cancelled && r.cancelFailure!=null)failure=r.cancelFailure;
    if(failure==RuntimeFailure.Code.cancelled)emit(r,"generationCancelled",null,null);
    else if(failure!=null)emit(r,"generationFailed",null,failure.name());
    else if(!r.hasNonBlankText)emit(r,"generationFailed",null,RuntimeFailure.Code.generationFailed.name());
    else emit(r,"generationCompleted",null,null,metrics);
    if(closingLlm!=null) {
      CompletableFuture<Void> f=closingLlm;closingLlm=null;
      RuntimeFailure.Code pendingCloseFailure=closeFailure;closeFailure=null;
      try { closeIdleLlm();if(pendingCloseFailure!=null)f.completeExceptionally(new RuntimeFailure(pendingCloseFailure));else f.complete(null); }catch(Throwable e) { f.completeExceptionally(sanitized(e,RuntimeFailure.Code.generationFailed)); }
    }
  }
  public CompletableFuture<Void> cancel(String id) {
    return submit(()-> {
      if(active!=null && active.id.equals(id))cancelActive();
      return null;
    });
  }
  private void cancelActive() {
    if(active==null)return;
    if(active.cancelRequested) {
      if(active.cancelFailure!=null)throw new RuntimeFailure(active.cancelFailure);
      return;
    }
    active.cancelRequested=true;
    // This is the official asynchronous cancel API. Keep the handle alive until
    // the terminal callback; a missing callback leaves it quarantined/busy.
    // A synchronous terminal callback only enqueues finish. This worker records
    // acceptance/failure before finish can run, including callback-then-throw.
    try { if(active.conversation!=null)active.conversation.cancel(); }
    catch(Throwable error) {
      active.cancelFailure=RuntimeFailure.Code.cancelFailed;
      throw new RuntimeFailure(active.cancelFailure);
    }
  }
  public CompletableFuture<Void> close(boolean isEmbedding) {
    return submit(()->requestClose(isEmbedding)).thenCompose(f->f);
  }
  private CompletableFuture<Void> requestClose(boolean isEmbedding) {
    if(isEmbedding) {
      closeIdleEmbedding();return CompletableFuture.completedFuture(null);
    }
    if(closingLlm!=null)return closingLlm;
    if(active!=null) {
      closingLlm=new CompletableFuture<>();
      try { cancelActive(); } catch(Throwable error) {
        // Cancellation failed, but the native call may still be running. Keep
        // worker/ownership alive until its terminal callback, then report error.
        closeFailure=sanitized(error,RuntimeFailure.Code.generationFailed).code;
      }
      return closingLlm;
    }
    closeIdleLlm();return CompletableFuture.completedFuture(null);
  }
  private void releaseProcessOwner() {
    synchronized(RUNTIME_LIFECYCLE) {
      if(processOwner==this && llm==null && embedding==null && active==null)processOwner=null;
    }
  }
  private void closeIdleLlm() {
    synchronized(RUNTIME_LIFECYCLE) {
      RuntimeBackend.Llm old=llm;if(old!=null)old.close();llm=null;releaseProcessOwner();
    }
  }
  private void closeIdleEmbedding() {
    synchronized(RUNTIME_LIFECYCLE) {
      if(embeddingQuarantined)throw new RuntimeFailure(RuntimeFailure.Code.embeddingCloseFailed);
      if(embedding==null)return;
      try { embedding.close(); }
      catch(Throwable error) {
        embeddingQuarantined=true;
        throw new RuntimeFailure(RuntimeFailure.Code.embeddingCloseFailed);
      }
      embedding=null;
      releaseProcessOwner();
    }
  }
  private void closeIdle() { closeIdleLlm();closeIdleEmbedding(); }
  public CompletableFuture<float[]> embed(String input) {
    return submit(()-> {
      if(embedding==null)throw new RuntimeFailure(RuntimeFailure.Code.notInitialized);
      if(embeddingQuarantined)throw new RuntimeFailure(RuntimeFailure.Code.embeddingCloseFailed);
      validateText(input);float[] vector=embedding.embed(input);
      if(vector==null || vector.length!=768)throw new RuntimeFailure(RuntimeFailure.Code.embeddingDimension);
      double squares=0;
      for(float v:vector) { if(!Float.isFinite(v))throw new RuntimeFailure(RuntimeFailure.Code.nonFiniteEmbedding);squares+=(double)v*v; }
      if(squares==0)throw new RuntimeFailure(RuntimeFailure.Code.zeroEmbedding);
      return vector.clone();
    });
  }
  public synchronized CompletableFuture<Void> dispose() {
    if(disposal!=null)return disposal;
    disposed=true;
    disposal=queue(()-> {
      CompletableFuture<Void> llmClose=requestClose(false);
      CompletableFuture<Void> embeddingClose=requestClose(true);
      return CompletableFuture.allOf(llmClose,embeddingClose);
    }).thenCompose(f->f).whenComplete((v,e)->worker.shutdown());
    return disposal;
  }
  private static void validateText(String text) {
    if(text==null || text.trim().isEmpty() || text.length()>32768)throw new RuntimeFailure(RuntimeFailure.Code.invalidRequest);
  }
  public boolean llmLoaded() { return llm!=null; }
  public boolean embeddingLoaded() { return embedding!=null; }
  public boolean embeddingQuarantined() { return embeddingQuarantined; }
}
