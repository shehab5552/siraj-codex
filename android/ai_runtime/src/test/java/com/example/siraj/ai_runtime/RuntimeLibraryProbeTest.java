package com.example.siraj.ai_runtime;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.FutureTask;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/** Pure Java contract runner; no Android SDK, fake engine or inference claim. */
public final class RuntimeLibraryProbeTest {
  private static int passed;

  private static void check(boolean value) {
    if (!value) throw new AssertionError("Library probe contract failed");
  }

  private static void failure(RuntimeFailure.Code code, Runnable action) {
    try {
      action.run();
      throw new AssertionError("Expected typed failure: " + code);
    } catch (RuntimeFailure actual) {
      check(actual.code == code);
    }
  }

  private static RuntimeLibraryProbe.Access access(Runnable require, Runnable load) {
    return new RuntimeLibraryProbe.Access() {
      public void requireEngineClass() { require.run(); }
      public void loadJni() { load.run(); }
    };
  }

  public static void main(String[] args) throws Exception {
    RuntimeLibraryProbe good = new RuntimeLibraryProbe(access(() -> {}, () -> {}));
    failure(RuntimeFailure.Code.unsupportedAbi, () -> good.load(new String[] {"armeabi-v7a"})); passed++;
    failure(RuntimeFailure.Code.unsupportedAbi, () -> good.load(null)); passed++;
    RuntimeLibraryProbe missing = new RuntimeLibraryProbe(new RuntimeLibraryProbe.Access() {
      public void requireEngineClass() throws ClassNotFoundException { throw new ClassNotFoundException(); }
      public void loadJni() { throw new AssertionError("Must reject before JNI"); }
    });
    failure(RuntimeFailure.Code.dependencyMissing, () -> missing.load(new String[] {"x86_64"})); passed++;
    RuntimeLibraryProbe incompatible = new RuntimeLibraryProbe(access(() -> {throw new UnsupportedClassVersionError();}, () -> {}));
    failure(RuntimeFailure.Code.dependencyIncompatible, () -> incompatible.load(new String[] {"x86_64"})); passed++;
    RuntimeLibraryProbe noJni = new RuntimeLibraryProbe(access(() -> {}, () -> {throw new UnsatisfiedLinkError();}));
    failure(RuntimeFailure.Code.jniMissing, () -> noJni.load(new String[] {"x86_64"})); passed++;
    RuntimeLibraryProbe.Status status = good.load(new String[] {"armeabi-v7a", "arm64-v8a", "x86_64"});
    check(status.jniLoaded && status.abi.equals("arm64-v8a") && status.declaredVersion.equals("0.19.0")); passed++;
    AtomicInteger loads = new AtomicInteger();
    CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
    RuntimeLibraryProbe serial = new RuntimeLibraryProbe(access(() -> {}, () -> {
      loads.incrementAndGet(); entered.countDown();
      try { check(release.await(5, TimeUnit.SECONDS)); }
      catch (InterruptedException error) { throw new AssertionError(error); }
    }));
    FutureTask<RuntimeLibraryProbe.Status> first = new FutureTask<>(() -> serial.load(new String[] {"x86_64"}));
    FutureTask<RuntimeLibraryProbe.Status> second = new FutureTask<>(() -> serial.load(new String[] {"x86_64"}));
    new Thread(first).start(); check(entered.await(5, TimeUnit.SECONDS));
    new Thread(second).start(); release.countDown();
    check(first.get(5, TimeUnit.SECONDS) == second.get(5, TimeUnit.SECONDS));
    check(loads.get() == 1); passed++;
    System.out.println("{\"native_library_contracts_passed\":" + passed + ",\"failed\":0,\"inference_proven\":false}");
  }
}
