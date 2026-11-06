package com.example.siraj.ai_runtime;
import java.io.File;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

/** Contract fakes only; these tests do not demonstrate JNI or model execution. */
public final class RuntimeManagerTest {
  static final class Fake implements RuntimeBackend {
    volatile Callback callback;
    volatile boolean cancelled;
    volatile int closed, conversations;
    volatile float[] vector = vector();
    public Llm loadLlm(File path) { return new Llm() {
      public Conversation conversation(String system) {
        conversations++;
        return new Conversation() {
          public void start(String input, Callback cb) { callback=cb; }
          public void cancel() { cancelled=true; }
          public void close() { closed++; }
        };
      }
      public void close() { closed++; }
    }; }
    public Embedding loadEmbedding(File path) { return new Embedding() {
      public float[] embed(String input) { return vector; }
      public void close() { closed++; }
    }; }
  }
  static float[] vector() { float[] v=new float[768];v[0]=1;return v; }
  static void await(CompletableFuture<?> f) throws Exception { f.get(3,TimeUnit.SECONDS); }
  static void failure(CompletableFuture<?> f, RuntimeFailure.Code expected) throws Exception {
    try { await(f);throw new AssertionError("expected "+expected); }
    catch(ExecutionException e) { if (!(e.getCause() instanceof RuntimeFailure r) || r.code!=expected) throw new AssertionError(e); }
  }
  static RuntimeManager create(Fake b,List<String> events) {
    return new RuntimeManager(b,(id,embedding)->new File("verified-test-only"),(id,type,seq,text,code)->events.add(id+":"+type+":"+seq));
  }
  static void check(boolean b) { if(!b)throw new AssertionError(); }
  public static void main(String[] args) throws Exception {
    AtomicInteger passed=new AtomicInteger();
    Fake b=new Fake();List<String> es=new CopyOnWriteArrayList<>();RuntimeManager m=create(b,es);
    failure(m.generate("r0","system","input"),RuntimeFailure.Code.notInitialized);passed.incrementAndGet();
    await(m.initialize("llm",false));check(m.llmLoaded());
    failure(m.initialize("llm",false),RuntimeFailure.Code.busy);passed.incrementAndGet();
    await(m.generate("r1","system","input"));failure(m.generate("r2","system","input"),RuntimeFailure.Code.busy);passed.incrementAndGet();
    b.callback.chunk("a");b.callback.chunk("b");b.callback.done();b.callback.done();await(m.close(false));
    check(es.equals(List.of("r1:generationStarted:0","r1:generationChunk:1","r1:generationChunk:2","r1:generationCompleted:3")));passed.incrementAndGet();
    await(m.initialize("llm",false));await(m.generate("r3","system","input"));RuntimeBackend.Callback stale=b.callback;
    await(m.cancel("r3"));check(b.cancelled);stale.chunk("late");stale.done();await(m.close(false));
    check(es.stream().filter(x->x.contains("r3:generationCancelled")).count()==1);check(es.stream().noneMatch(x->x.contains("r3:generationChunk")));passed.incrementAndGet();
    await(m.initialize("llm",false));await(m.generate("r4","system","input"));stale.chunk("old");b.callback.chunk("new");b.callback.done();await(m.close(false));
    check(es.stream().filter(x->x.contains("r4:generationChunk")).count()==1);check(b.conversations==3);passed.incrementAndGet();
    await(m.initialize("llm",false));failure(m.generate("r4","system","input"),RuntimeFailure.Code.invalidRequest);await(m.close(false));passed.incrementAndGet();
    await(m.initialize("embedding",true));check(m.embeddingLoaded());await(m.embed("input"));passed.incrementAndGet();
    b.vector=new float[3];failure(m.embed("input"),RuntimeFailure.Code.embeddingDimension);passed.incrementAndGet();
    b.vector=vector();b.vector[0]=Float.NaN;failure(m.embed("input"),RuntimeFailure.Code.nonFiniteEmbedding);passed.incrementAndGet();
    b.vector=new float[768];failure(m.embed("input"),RuntimeFailure.Code.zeroEmbedding);passed.incrementAndGet();
    await(m.close(true));await(m.initialize("llm",false));await(m.generate("r5","system","input"));CompletableFuture<Void> disposing=m.dispose();
    b.callback.done();await(disposing);failure(m.initialize("llm",false),RuntimeFailure.Code.disposed);check(!m.llmLoaded());passed.incrementAndGet();
    System.out.println("RuntimeManagerTest: "+passed+" passed (fake contracts, not inference)");
  }
}
