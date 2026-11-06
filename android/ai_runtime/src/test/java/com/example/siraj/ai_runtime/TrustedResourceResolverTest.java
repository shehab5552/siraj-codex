package com.example.siraj.ai_runtime;
import java.io.File;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
public final class TrustedResourceResolverTest {
  interface Action { void run(); }
  static void failure(Action action,RuntimeFailure.Code code) {
    try { action.run();throw new AssertionError("expected "+code); }
    catch(RuntimeFailure f) { if(f.code!=code)throw new AssertionError(f.code); }
  }
  public static void main(String[] args) throws Exception {
    Path temp=Files.createTempDirectory("b08-resolver-");
    try {
      byte[] data=new byte[32];System.arraycopy("LITERTLM".getBytes(java.nio.charset.StandardCharsets.US_ASCII),0,data,0,8);
      String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
      Files.write(temp.resolve("model.litertlm"),data);
      Map<String,TrustedResourceResolver.Pin> pins=Map.of("model",new TrustedResourceResolver.Pin("model.litertlm",hash,data.length,false));
      TrustedResourceResolver r=new TrustedResourceResolver(temp.toFile(),pins);
      if(!r.resolve("model",false).isFile())throw new AssertionError();
      failure(()->r.resolve("model",true),RuntimeFailure.Code.resourceUnavailable);
      failure(()->r.resolve("/etc/passwd",false),RuntimeFailure.Code.resourceUnavailable);
      failure(()->new TrustedResourceResolver(temp.toFile(),Map.of()).resolve("model",false),RuntimeFailure.Code.resourceUnavailable);
      data[12]=1;Files.write(temp.resolve("model.litertlm"),data);
      failure(()->r.resolve("model",false),RuntimeFailure.Code.integrityFailure);
      Files.move(temp.resolve("model.litertlm"),temp.resolve("other"));Files.createSymbolicLink(temp.resolve("model.litertlm"),temp.resolve("other"));
      failure(()->r.resolve("model",false),RuntimeFailure.Code.unsafeResourcePath);
      System.out.println("TrustedResourceResolverTest: 6 passed (isolated temporary files)");
    } finally { try(var stream=Files.list(temp)) { for(Path p:stream.toList())Files.delete(p); }Files.delete(temp); }
  }
}
