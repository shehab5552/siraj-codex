package com.example.siraj.ai_runtime;

import java.io.File;
import java.util.*;
import java.util.concurrent.*;

/** Deterministic lifecycle contracts only, never model execution evidence. */
public final class RuntimeLifecycleHardeningTest {
  static final class Fake implements RuntimeBackend {
    Callback callback;
    boolean throwCancel, synchronousCancel, throwEmbeddingClose;
    int cancellations, conversationCloses, llmCloses, embeddingCloses, embeddingLoads;
    public Llm loadLlm(File ignored) { return new Llm() {
      public Conversation conversation(String ignored) { return new Conversation() {
        public void start(String ignored, Callback cb) { callback=cb; }
        public void cancel() {
          cancellations++;
          if(synchronousCancel)callback.failed(RuntimeFailure.Code.cancelled);
          if(throwCancel)throw new IllegalStateException("private SDK exception");
        }
        public void close() { conversationCloses++; }
      }; }
      public void close() { llmCloses++; }
    }; }
    public Embedding loadEmbedding(File ignored) {
      embeddingLoads++;
      return new Embedding() {
        public float[] embed(String ignored) { float[] v=new float[768];v[0]=1;return v; }
        public void close() { embeddingCloses++;if(throwEmbeddingClose)throw new IllegalStateException("private close failure"); }
      };
    }
  }
  static final class Fixture implements AutoCloseable {
    final Fake backend=new Fake();
    final List<String> events=new CopyOnWriteArrayList<>();
    final List<String> chunks=new CopyOnWriteArrayList<>();
    final RuntimeManager manager=new RuntimeManager(backend,(id,e)->new File("test-only-verified"),
        (id,type,seq,text,code,metrics)-> {events.add(id+":"+type+":"+code);if(text!=null)chunks.add(text);});
    void start() throws Exception { await(manager.initialize("llm",false));await(manager.generate("one","system","input")); }
    void drain() throws Exception { await(manager.cancel("absent")); }
    String terminal() { return events.get(events.size()-1); }
    public void close() throws Exception {
      CompletableFuture<Void> disposing=manager.dispose();
      if(backend.callback!=null)backend.callback.failed(RuntimeFailure.Code.cancelled);
      try { await(disposing); }catch(ExecutionException ignored) { /* Intentional failure fixtures. */ }
    }
  }
  interface Case { void run() throws Exception; }
  static int passed;
  static void test(String name,Case body) throws Exception { body.run();passed++;System.out.println("PASS "+name); }
  static void check(boolean value) { if(!value)throw new AssertionError("lifecycle invariant"); }
  static void await(CompletableFuture<?> f) throws Exception { f.get(3,TimeUnit.SECONDS); }
  static void failure(CompletableFuture<?> f,String code) throws Exception {
    try { await(f);throw new AssertionError("expected "+code); }
    catch(ExecutionException e) {
      check(e.getCause() instanceof RuntimeFailure);
      RuntimeFailure r=(RuntimeFailure)e.getCause();check(r.code.name().equals(code));check(r.getMessage().equals(code));check(r.getCause()==null);
    }
  }
  public static void main(String[] args) throws Exception {
    Thread.setDefaultUncaughtExceptionHandler((t,e)-> {e.printStackTrace();System.exit(1);});
    if(args.length>1 || (args.length==1 && !args[0].equals("embedding-only")))throw new IllegalArgumentException("expected optional embedding-only");
    if(args.length==0) {
    test("accepted cancel waits for delayed native terminal",()-> {
      try(Fixture f=new Fixture()) {
        f.start();await(f.manager.cancel("one"));f.drain();check(f.events.size()==1);check(f.backend.conversationCloses==0);
        failure(f.manager.generate("two","system","input"),"busy");
        f.backend.callback.failed(RuntimeFailure.Code.cancelled);f.drain();
        check(f.terminal().equals("one:generationCancelled:null"));check(f.backend.conversationCloses==1);
      }
    });
    test("cancel followed by normal completion is completed",()-> {
      try(Fixture f=new Fixture()) {
        f.start();f.backend.callback.chunk("valid text");f.drain();await(f.manager.cancel("one"));
        f.backend.callback.done();f.drain();check(f.terminal().equals("one:generationCompleted:null"));
      }
    });
    test("normal completion preserves text generated after cancel acceptance",()-> {
      try(Fixture f=new Fixture()) {
        f.start();f.backend.callback.chunk("prefix ");f.drain();await(f.manager.cancel("one"));
        f.backend.callback.chunk("suffix");f.backend.callback.done();f.drain();
        check(f.terminal().contains("generationCompleted"));check(String.join("",f.chunks).equals("prefix suffix"));
      }
    });
    test("cancel followed by native failure is failed",()-> {
      try(Fixture f=new Fixture()) {
        f.start();await(f.manager.cancel("one"));f.backend.callback.failed(RuntimeFailure.Code.generationFailed);f.drain();
        check(f.terminal().equals("one:generationFailed:generationFailed"));
      }
    });
    test("cancel API throws retains busy ownership until terminal",()-> {
      try(Fixture f=new Fixture()) {
        f.start();f.backend.throwCancel=true;failure(f.manager.cancel("one"),"cancelFailed");
        check(f.events.size()==1);check(f.backend.conversationCloses==0);failure(f.manager.generate("two","system","input"),"busy");
        f.backend.callback.failed(RuntimeFailure.Code.cancelled);f.drain();check(f.terminal().equals("one:generationFailed:cancelFailed"));
      }
    });
    test("failed cancel may still end in normal completion",()-> {
      try(Fixture f=new Fixture()) {
        f.start();f.backend.callback.chunk("valid text");f.drain();f.backend.throwCancel=true;
        failure(f.manager.cancel("one"),"cancelFailed");f.backend.callback.done();f.drain();check(f.terminal().contains("generationCompleted"));
      }
    });
    test("synchronous terminal during accepted cancel",()-> {
      try(Fixture f=new Fixture()) {
        f.start();f.backend.synchronousCancel=true;await(f.manager.cancel("one"));f.drain();check(f.terminal().contains("generationCancelled"));check(f.backend.conversationCloses==1);
      }
    });
    test("synchronous terminal followed by API throw never reports cancel success",()-> {
      try(Fixture f=new Fixture()) {
        f.start();f.backend.synchronousCancel=true;f.backend.throwCancel=true;failure(f.manager.cancel("one"),"cancelFailed");f.drain();
        check(f.terminal().equals("one:generationFailed:cancelFailed"));
      }
    });
    test("duplicate cancel requests call SDK once",()-> {
      try(Fixture f=new Fixture()) { f.start();await(f.manager.cancel("one"));await(f.manager.cancel("one"));check(f.backend.cancellations==1); }
    });
    test("duplicate and stale callbacks cannot terminate next generation",()-> {
      try(Fixture f=new Fixture()) {
        f.start();RuntimeBackend.Callback stale=f.backend.callback;await(f.manager.cancel("one"));stale.failed(RuntimeFailure.Code.cancelled);f.drain();
        await(f.manager.generate("two","system","input"));stale.chunk("old");stale.done();stale.failed(RuntimeFailure.Code.generationFailed);
        f.backend.callback.chunk("current");f.backend.callback.done();f.drain();
        check(f.events.stream().filter(e->e.contains("one:generationCancelled")).count()==1);
        check(f.events.stream().filter(e->e.contains("two:generationCompleted")).count()==1);check(f.backend.conversationCloses==2);
      }
    });
    test("close waits for native terminal then destroys conversation and LLM",()-> {
      try(Fixture f=new Fixture()) {
        f.start();await(f.manager.cancel("one"));CompletableFuture<Void> close=f.manager.close(false);f.drain();
        check(!close.isDone());check(f.backend.llmCloses==0);f.backend.callback.failed(RuntimeFailure.Code.cancelled);await(close);
        check(f.backend.llmCloses==1);check(f.backend.conversationCloses==1);check(!f.manager.llmLoaded());
      }
    });
    test("dispose during cancellation waits for native terminal",()-> {
      try(Fixture f=new Fixture()) {
        f.start();await(f.manager.cancel("one"));CompletableFuture<Void> dispose=f.manager.dispose();
        check(!dispose.isDone());f.backend.callback.failed(RuntimeFailure.Code.cancelled);await(dispose);
        check(f.backend.conversationCloses==1);check(f.backend.llmCloses==1);check(f.backend.cancellations==1);
      }
    });
    test("Activity replacement stays busy until previous Native terminal and cleanup",()-> {
      try(Fixture old=new Fixture();Fixture replacement=new Fixture()) {
        old.start();await(old.manager.cancel("one"));CompletableFuture<Void> disposing=old.manager.dispose();
        failure(replacement.manager.initialize("llm",false),"busy");check(!disposing.isDone());
        old.backend.callback.failed(RuntimeFailure.Code.cancelled);await(disposing);
        await(replacement.manager.initialize("llm",false));check(replacement.manager.llmLoaded());
      }
    });
    }
    test("normal embedding close clears ownership only after success",()-> {
      try(Fixture f=new Fixture()) {
        await(f.manager.initialize("embed",true));check(f.manager.embeddingLoaded());await(f.manager.close(true));
        check(!f.manager.embeddingLoaded());check(f.backend.embeddingCloses==1);
      }
    });
    test("repeated successful close never re-closes deleted SDK handle",()-> {
      try(Fixture f=new Fixture()) {
        await(f.manager.initialize("embed",true));await(f.manager.close(true));await(f.manager.close(true));check(f.backend.embeddingCloses==1);
      }
    });
    test("reinitialize after confirmed successful embedding cleanup",()-> {
      try(Fixture f=new Fixture()) {
        await(f.manager.initialize("embed",true));await(f.manager.close(true));await(f.manager.initialize("embed",true));
        check(f.manager.embeddingLoaded());check(f.backend.embeddingLoads==2);await(f.manager.embed("query"));
      }
    });
    test("embedding close failure retains reference and accurate loaded status",()-> {
      // Last group intentionally quarantines a handle for this process lifetime.
      Fixture f=new Fixture();await(f.manager.initialize("embed",true));f.backend.throwEmbeddingClose=true;
      failure(f.manager.close(true),"embeddingCloseFailed");check(f.manager.embeddingLoaded());check(f.backend.embeddingCloses==1);
      test("failed-close embedding cannot be used",()->failure(f.manager.embed("query"),"embeddingCloseFailed"));
      test("no replacement embedding while unresolved",()-> {failure(f.manager.initialize("embed",true),"embeddingCloseFailed");check(f.backend.embeddingLoads==1);});
      test("unsafe SDK close retry forbidden even if fake would later succeed",()-> {
        f.backend.throwEmbeddingClose=false;failure(f.manager.close(true),"embeddingCloseFailed");check(f.backend.embeddingCloses==1);
      });
      test("dispose after failure preserves quarantined ownership",()-> {
        failure(f.manager.dispose(),"embeddingCloseFailed");check(f.manager.embeddingLoaded());check(f.backend.embeddingCloses==1);
        failure(f.manager.dispose(),"embeddingCloseFailed");
      });
      test("new manager cannot bypass process quarantine",()-> {
        try(Fixture replacement=new Fixture()) {failure(replacement.manager.initialize("embed",true),"embeddingCloseFailed");check(replacement.backend.embeddingLoads==0);}
      });
    });
    System.out.println("RuntimeLifecycleHardeningTest: "+passed+" passed (fake contracts, not inference)");
  }
}
