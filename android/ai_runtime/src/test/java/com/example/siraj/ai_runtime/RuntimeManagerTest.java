package com.example.siraj.ai_runtime;
import java.io.File;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

/** Contract fakes only; these tests do not demonstrate JNI or model execution. */
public final class RuntimeManagerTest {
  static final class Fake implements RuntimeBackend {
    volatile Callback callback;
    volatile boolean cancelled, throwCancel, throwCloseOnce;
    final CountDownLatch cancelEntered=new CountDownLatch(1);
    volatile int closed, conversations, initializations;
    volatile boolean failInitialize;
    volatile CountDownLatch initializeEntered, initializeRelease;
    volatile float[] vector = vector();
    public Llm loadLlm(File path) {
      initializations++;
      if(initializeEntered!=null) {
        initializeEntered.countDown();
        try { if(!initializeRelease.await(3,TimeUnit.SECONDS))throw new AssertionError("test gate timed out"); }
        catch(InterruptedException error) {Thread.currentThread().interrupt();throw new IllegalStateException("test interrupted");}
      }
      if(failInitialize)throw new IllegalStateException("isolated test initialization failure");
      return new Llm() {
      public Conversation conversation(String system) {
        conversations++;
        return new Conversation() {
          public void start(String input, Callback cb) { callback=cb; }
          public void cancel() { cancelled=true;cancelEntered.countDown();if(throwCancel)throw new IllegalStateException("test cancel error"); }
          public void close() { closed++; }
        };
      }
      public void close() { if(throwCloseOnce) {throwCloseOnce=false;throw new IllegalStateException("test close failure");}closed++; }
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
    return new RuntimeManager(b,(id,embedding)->new File("verified-test-only"),(id,type,seq,text,code,metrics)->events.add(id+":"+type+":"+seq));
  }
  static void check(boolean b) { if(!b)throw new AssertionError(); }
  public static void main(String[] args) throws Exception {
    Thread.setDefaultUncaughtExceptionHandler((thread,error)-> {error.printStackTrace();System.exit(1);});
    AtomicInteger passed=new AtomicInteger();
    Fake b=new Fake();List<String> es=new CopyOnWriteArrayList<>();RuntimeManager m=create(b,es);
    failure(m.generate("r0","system","input"),RuntimeFailure.Code.notInitialized);passed.incrementAndGet();
    await(m.initialize("llm",false));check(m.llmLoaded());
    failure(m.initialize("llm",false),RuntimeFailure.Code.busy);passed.incrementAndGet();
    await(m.generate("r1","system","input"));failure(m.generate("r2","system","input"),RuntimeFailure.Code.busy);passed.incrementAndGet();
    b.callback.chunk("a");b.callback.chunk("b");b.callback.done();b.callback.done();await(m.close(false));
    check(es.equals(List.of("r1:generationStarted:0","r1:generationChunk:1","r1:generationChunk:2","r1:generationCompleted:3")));passed.incrementAndGet();
    await(m.initialize("llm",false));await(m.generate("r3","system","input"));RuntimeBackend.Callback stale=b.callback;
    await(m.cancel("r3"));check(b.cancelled);stale.failed(RuntimeFailure.Code.cancelled);stale.chunk("late");await(m.close(false));
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
    Fake throwing=new Fake();throwing.throwCancel=true;RuntimeManager guarded=create(throwing,new CopyOnWriteArrayList<>());
    await(guarded.initialize("llm",false));await(guarded.generate("throw-cancel","system","input"));
    CompletableFuture<Void> pending=guarded.dispose();check(throwing.cancelEntered.await(2,TimeUnit.SECONDS));
    try { pending.get(50,TimeUnit.MILLISECONDS);throw new AssertionError("must drain native first"); }
    catch(TimeoutException expected) { /* Quarantined until actual terminal. */ }
    throwing.callback.done();failure(pending,RuntimeFailure.Code.cancelFailed);check(!guarded.llmLoaded());check(throwing.closed==2);passed.incrementAndGet();
    Fake retry=new Fake();retry.throwCancel=true;retry.throwCloseOnce=true;RuntimeManager recovering=create(retry,new CopyOnWriteArrayList<>());
    await(recovering.initialize("llm",false));await(recovering.generate("close-failure","system","input"));
    CompletableFuture<Void> firstClose=recovering.close(false);retry.callback.done();failure(firstClose,RuntimeFailure.Code.generationFailed);
    await(recovering.close(false));retry.throwCancel=false;
    await(recovering.initialize("llm",false));await(recovering.generate("clean-reload","system","input"));
    CompletableFuture<Void> secondClose=recovering.close(false);retry.callback.done();await(secondClose);await(recovering.dispose());passed.incrementAndGet();
    Fake blank=new Fake();List<String> blankEvents=new CopyOnWriteArrayList<>();RuntimeManager blankManager=create(blank,blankEvents);
    await(blankManager.initialize("llm",false));await(blankManager.generate("blank","system","input"));blank.callback.chunk("   ");blank.callback.done();await(blankManager.close(false));
    check(blankEvents.stream().anyMatch(e->e.contains("generationFailed")));check(blankEvents.stream().noneMatch(e->e.contains("generationCompleted")));await(blankManager.dispose());passed.incrementAndGet();
    Fake gated=new Fake();gated.initializeEntered=new CountDownLatch(1);gated.initializeRelease=new CountDownLatch(1);
    RuntimeManager serial=create(gated,new CopyOnWriteArrayList<>());CompletableFuture<Void> init1=serial.initialize("llm",false);
    check(gated.initializeEntered.await(2,TimeUnit.SECONDS));CompletableFuture<Void> init2=serial.initialize("llm",false);check(!init2.isDone());
    gated.initializeRelease.countDown();await(init1);failure(init2,RuntimeFailure.Code.busy);check(gated.initializations==1);await(serial.dispose());passed.incrementAndGet();
    Fake broken=new Fake();broken.failInitialize=true;RuntimeManager retryInit=create(broken,new CopyOnWriteArrayList<>());
    failure(retryInit.initialize("llm",false),RuntimeFailure.Code.initializationFailed);check(!retryInit.llmLoaded());broken.failInitialize=false;
    await(retryInit.initialize("llm",false));check(retryInit.llmLoaded());await(retryInit.dispose());passed.incrementAndGet();
    System.out.println("RuntimeManagerTest: "+passed+" passed (fake contracts, not inference)");
  }
}
