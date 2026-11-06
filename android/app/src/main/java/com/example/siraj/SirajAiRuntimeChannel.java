package com.example.siraj;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import com.example.siraj.ai_runtime.*;
import io.flutter.plugin.common.*;
import java.util.*;
import java.util.concurrent.*;

/** Versioned Flutter transport only. No auth, retrieval policy or SQLite logic. */
public final class SirajAiRuntimeChannel implements EventChannel.StreamHandler {
  private final Handler main=new Handler(Looper.getMainLooper());
  private final ExecutorService probeWorker=Executors.newSingleThreadExecutor();
  private final RuntimeLibraryProbe probe=new RuntimeLibraryProbe();
  private final RuntimeManager runtime;
  private final MethodChannel methods;
  private final EventChannel events;
  private EventChannel.EventSink sink;
  private boolean disposed;
  private volatile long listenerEpoch;
  private final RequestOwnership requestListeners=new RequestOwnership();
  public SirajAiRuntimeChannel(Context context,BinaryMessenger messenger) {
    runtime=new RuntimeManager(new LiteRtBackend(AiResourceCatalog.benchmarkEnabled()),AiResourceCatalog.create(context.getFilesDir()),(id,type,seq,text,code,metrics)-> {
      Map<String,Object> data=new HashMap<>();data.put("requestId",id);data.put("type",type);data.put("sequence",seq);
      if(metrics!=null)data.put("benchmark",metrics.toMap());
      if(text!=null)data.put("text",text);if(code!=null)data.put("code",code);
      RequestOwnership.Lease lease=requestListeners.current(id);
      if(type.equals("generationCompleted") || type.equals("generationFailed") || type.equals("generationCancelled"))requestListeners.release(id,lease);
      main.post(()-> { if(!disposed && sink!=null && lease!=null && lease.listenerEpoch==listenerEpoch)sink.success(data); });
    });
    methods=new MethodChannel(messenger,"siraj/ai_runtime/methods_v1");
    events=new EventChannel(messenger,"siraj/ai_runtime/events_v1");
    events.setStreamHandler(this);methods.setMethodCallHandler(this::handle);
  }
  private static String text(MethodCall call,String key) {
    Object value=call.argument(key);if(!(value instanceof String))throw new RuntimeFailure(RuntimeFailure.Code.invalidRequest);return (String)value;
  }
  private void handle(MethodCall call,MethodChannel.Result result) {
    if(disposed) { result.error("disposed","disposed",null);return; }
    long started=System.nanoTime();
    try {
      switch(call.method) {
        case "getRuntimeStatus":
          complete(CompletableFuture.supplyAsync(()-> {
            RuntimeLibraryProbe.Status s=probe.load(Build.SUPPORTED_ABIS);
            Map<String,Object> out=new HashMap<>();out.put("declaredRuntimeVersion",s.declaredVersion);out.put("abi",s.abi);out.put("jniLoaded",s.jniLoaded);
            out.put("llmInitialized",runtime.llmLoaded());out.put("embeddingInitialized",runtime.embeddingLoaded());out.put("embeddingQuarantined",runtime.embeddingQuarantined());out.put("productionResourcesApproved",false);out.put("nativeHeapAllocatedBytes",android.os.Debug.getNativeHeapAllocatedSize());out.put("sampledPssKb",android.os.Debug.getPss());return out;
          },probeWorker),result);break;
        case "initializeLlm":case "initializeEmbedding":
          complete(runtime.initialize(text(call,"resourceId"),call.method.equals("initializeEmbedding")).thenApply(v-> {
            Map<String,Object> out=new HashMap<>();out.put("initialized",true);out.put("elapsedMs",(System.nanoTime()-started)/1000000.0);return out;
          }),result);break;
        case "generate":
          if(sink==null)throw new RuntimeFailure(RuntimeFailure.Code.invalidRequest);
          String requestId=text(call,"requestId");
          String system=text(call,"systemInstruction"), input=text(call,"input");
          RequestOwnership.Lease owned=requestListeners.claim(requestId,listenerEpoch);
          complete(runtime.generate(requestId,system,input).whenComplete((v,e)-> { if(e!=null)requestListeners.release(requestId,owned); }).thenApply(v->Collections.singletonMap("accepted",true)),result);break;
        case "cancelGeneration":complete(runtime.cancel(text(call,"requestId")),result);break;
        case "closeLlm":complete(runtime.close(false),result);break;
        case "closeEmbedding":complete(runtime.close(true),result);break;
        case "embed":
          complete(runtime.embed(text(call,"input")).thenApply(vector-> {
            List<Double> values=new ArrayList<>(vector.length);double squares=0;
            for(float value:vector) { values.add((double)value);squares+=(double)value*value; }
            Map<String,Object> out=new HashMap<>();out.put("vector",values);out.put("l2Norm",Math.sqrt(squares));out.put("elapsedMs",(System.nanoTime()-started)/1000000.0);out.put("options","sdkNullableDefaultsNotDatasetParity");return out;
          }),result);break;
        default:result.notImplemented();
      }
    } catch(RuntimeException e) { fail(result,e); }
  }
  private <T> void complete(CompletableFuture<T> future,MethodChannel.Result result) {
    future.whenComplete((value,error)->main.post(()-> {
      if(error!=null)fail(result,error);else if(disposed)result.error("disposed","disposed",null);else result.success(value);
    }));
  }
  private void fail(MethodChannel.Result result,Throwable error) {
    while(error instanceof CompletionException && error.getCause()!=null)error=error.getCause();
    String code=error instanceof RuntimeFailure?((RuntimeFailure)error).code.name():"generationFailed";
    result.error(code,code,null);
  }
  @Override public void onListen(Object arguments,EventChannel.EventSink events) { listenerEpoch++;sink=events; }
  @Override public void onCancel(Object arguments) {
    listenerEpoch++;sink=null;runtime.close(false);
  }
  public void dispose() {
    if(disposed)return;disposed=true;listenerEpoch++;sink=null;requestListeners.clear();methods.setMethodCallHandler(null);events.setStreamHandler(null);
    runtime.dispose();probeWorker.shutdown();
  }
}
