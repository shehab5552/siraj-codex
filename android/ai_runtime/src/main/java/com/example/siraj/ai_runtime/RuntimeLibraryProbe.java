package com.example.siraj.ai_runtime;

/** Plain Java boundary: no LiteRT/Kotlin types escape to Flutter's Kotlin app. */
public final class RuntimeLibraryProbe {
  public interface Access {
    void requireEngineClass() throws ClassNotFoundException;
    void loadJni();
  }

  public static final class Status {
    public final String declaredVersion;
    public final String abi;
    public final boolean jniLoaded;

    Status(String abi) {
      this.declaredVersion = "0.19.0";
      this.abi = abi;
      this.jniLoaded = true;
    }
  }

  private final Access access;
  private Status loaded;

  public RuntimeLibraryProbe() {
    this(new Access() {
      public void requireEngineClass() throws ClassNotFoundException {
        Class.forName("com.google.ai.edge.litertlm.Engine", false,
            RuntimeLibraryProbe.class.getClassLoader());
      }
      public void loadJni() { System.loadLibrary("litertlm_jni"); }
    });
  }

  public RuntimeLibraryProbe(Access access) {
    this.access = java.util.Objects.requireNonNull(access);
  }

  public synchronized Status load(String[] supportedAbis) {
    if (loaded != null) return loaded;
    String selected = null;
    if (supportedAbis != null) {
      for (String abi : supportedAbis) {
        if ("arm64-v8a".equals(abi) || "x86_64".equals(abi)) {
          selected = abi;
          break;
        }
      }
    }
    if (selected == null) throw new RuntimeFailure(RuntimeFailure.Code.unsupportedAbi);
    try {
      access.requireEngineClass();
      access.loadJni();
      loaded = new Status(selected);
      return loaded;
    } catch (ClassNotFoundException | NoClassDefFoundError error) {
      throw new RuntimeFailure(RuntimeFailure.Code.dependencyMissing);
    } catch (UnsatisfiedLinkError error) {
      throw new RuntimeFailure(RuntimeFailure.Code.jniMissing);
    } catch (LinkageError error) {
      throw new RuntimeFailure(RuntimeFailure.Code.dependencyIncompatible);
    }
  }
}
