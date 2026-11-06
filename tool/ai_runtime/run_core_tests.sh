#!/usr/bin/env bash
set -euo pipefail
# Pure Java contracts; fake boundary implementations exist in src/test only.
ai_test_dir=$(mktemp -d)
trap 'rm -rf "$ai_test_dir"' EXIT
java --module jdk.compiler/com.sun.tools.javac.Main -source 17 -target 17 \
  -d "$ai_test_dir" \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeFailure.java \
  android/ai_runtime/src/main/java/com/example/siraj/ai_runtime/RuntimeLibraryProbe.java \
  android/ai_runtime/src/test/java/com/example/siraj/ai_runtime/RuntimeLibraryProbeTest.java
java -cp "$ai_test_dir" com.example.siraj.ai_runtime.RuntimeLibraryProbeTest
