#!/usr/bin/env bash
set -euo pipefail
# Pure Java contracts; fake boundary implementations exist in src/test only.
ai_test_dir=$(mktemp -d)
trap 'rm -rf "$ai_test_dir"' EXIT
java --module jdk.compiler/com.sun.tools.javac.Main -source 17 -target 17 \
  -d "$ai_test_dir" \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeFailure.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeLibraryProbe.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeMetrics.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeBackend.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeManager.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RequestOwnership.java \
  android/ai_runtime/src/test/java/com/example/siraj/ai_runtime/RequestOwnershipTest.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/TrustedResourceResolver.java \
  android/ai_runtime/src/test/java/com/example/siraj/ai_runtime/TrustedResourceResolverTest.java \
  android/ai_runtime/src/test/java/com/example/siraj/ai_runtime/RuntimeManagerTest.java \
  android/ai_runtime/src/test/java/com/example/siraj/ai_runtime/RuntimeLifecycleHardeningTest.java \
  android/ai_runtime/src/test/java/com/example/siraj/ai_runtime/RuntimeLibraryProbeTest.java
java -cp "$ai_test_dir" com.example.siraj.ai_runtime.RuntimeLibraryProbeTest
java -cp "$ai_test_dir" com.example.siraj.ai_runtime.RuntimeManagerTest
java -cp "$ai_test_dir" com.example.siraj.ai_runtime.TrustedResourceResolverTest
java -cp "$ai_test_dir" com.example.siraj.ai_runtime.RequestOwnershipTest
java -cp "$ai_test_dir" com.example.siraj.ai_runtime.RuntimeLifecycleHardeningTest "$@"
