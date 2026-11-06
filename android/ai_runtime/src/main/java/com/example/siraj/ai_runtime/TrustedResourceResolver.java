package com.example.siraj.ai_runtime;
import java.io.*;
import java.security.*;
import java.util.*;

/** Fixed native catalog, app-private root. No path is accepted from Flutter.
 * Production supplies an empty catalog until an approved resource authority.
 * A caller must keep the private fixture directory immutable during load/use. */
public final class TrustedResourceResolver implements RuntimeManager.Resolver {
  public static final class Pin {
    final String filename,sha256;final long size;final boolean embedding;
    public Pin(String filename,String sha256,long size,boolean embedding) {
      if(!filename.matches("[A-Za-z0-9_.-]+") || filename.equals(".") || filename.equals("..") || !sha256.matches("[a-f0-9]{64}") || size<32)throw new IllegalArgumentException("Invalid native pin");
      this.filename=filename;this.sha256=sha256;this.size=size;this.embedding=embedding;
    }
  }
  private final File root;
  private final Map<String,Pin> pins;
  public TrustedResourceResolver(File root,Map<String,Pin> pins) {
    this.root=Objects.requireNonNull(root).getAbsoluteFile();this.pins=Collections.unmodifiableMap(new HashMap<>(pins));
  }
  @Override public File resolve(String id,boolean embedding) {
    Pin pin=pins.get(id);
    if(pin==null || pin.embedding!=embedding)throw new RuntimeFailure(RuntimeFailure.Code.resourceUnavailable);
    try {
      File file=new File(root,pin.filename);
      // Comparing the whole canonical path also rejects symlinked ancestors,
      // traversal and redirected fixture roots. No directory creation/deletion.
      if(!root.getCanonicalFile().equals(root) || !file.getCanonicalFile().equals(file.getAbsoluteFile()))throw new RuntimeFailure(RuntimeFailure.Code.unsafeResourcePath);
      if(!file.isFile() || !file.canRead() || file.length()!=pin.size)throw new RuntimeFailure(RuntimeFailure.Code.integrityFailure);
      long modified=file.lastModified();MessageDigest digest=MessageDigest.getInstance("SHA-256");
      byte[] buffer=new byte[65536];long count=0;
      try(InputStream input=new FileInputStream(file)) {
        int n;while((n=input.read(buffer))!=-1) { count+=n;if(count>pin.size)throw new RuntimeFailure(RuntimeFailure.Code.integrityFailure);digest.update(buffer,0,n); }
      }
      StringBuilder hex=new StringBuilder();for(byte b:digest.digest())hex.append(String.format(Locale.ROOT,"%02x",b&255));
      if(count!=pin.size || !hex.toString().equals(pin.sha256) || modified!=file.lastModified() || !file.getCanonicalFile().equals(file.getAbsoluteFile()))throw new RuntimeFailure(RuntimeFailure.Code.integrityFailure);
      try(DataInputStream input=new DataInputStream(new FileInputStream(file))) {
        byte[] magic=new byte[8];input.readFully(magic);
        if(!Arrays.equals(magic,new byte[]{'L','I','T','E','R','T','L','M'}))throw new RuntimeFailure(RuntimeFailure.Code.formatRejected);
      }
      return file;
    } catch(RuntimeFailure e) { throw e; }
    catch(IOException | NoSuchAlgorithmException e) { throw new RuntimeFailure(RuntimeFailure.Code.integrityFailure); }
  }
}
