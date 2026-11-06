package com.example.siraj.ai_runtime;
import java.util.concurrent.ConcurrentHashMap;
/** Per-request listener ownership, independent from asynchronous admission. */
public final class RequestOwnership {
  public static final class Lease {
    public final long listenerEpoch;
    Lease(long epoch) {listenerEpoch=epoch;}
  }
  private final ConcurrentHashMap<String,Lease> owners=new ConcurrentHashMap<>();
  public Lease claim(String id,long epoch) {Lease lease=new Lease(epoch);if(owners.putIfAbsent(id,lease)!=null)throw new RuntimeFailure(RuntimeFailure.Code.invalidRequest);return lease;}
  public Lease current(String id) {return owners.get(id);}
  public void release(String id,Lease lease) {if(lease!=null)owners.remove(id,lease);}
  public void clear() {owners.clear();}
}
