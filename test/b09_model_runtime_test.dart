import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/integrations/ai/managed_model_runtime.dart';
import 'package:siraj/integrations/ai/runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';

class TestBackend implements ModelBackend {
  int loads = 0, generations = 0, unloads = 0, cancels = 0;
  Completer<String>? paused;
  Completer<void>? loadPaused;
  Completer<void>? cancelPaused;
  ModelCapabilities? overrideCapabilities;
  RuntimeFailure? failure;
  @override
  Future<ModelCapabilities> load(
    ModelConfig config,
    TutorCancellation cancel,
  ) async {
    loads++;
    if (loadPaused != null) await loadPaused!.future;
    if (overrideCapabilities != null) return overrideCapabilities!;
    return ModelCapabilities(
      runtimeId: config.runtimeId,
      contextLength: config.contextLength,
      supportsCancellation: true,
    );
  }

  @override
  Future<String> generate(
    GenerationRequest request,
    TutorCancellation cancel,
  ) async {
    generations++;
    if (failure case final f?) throw f;
    return paused == null ? 'synthetic test output' : paused!.future;
  }

  @override
  Future<void> cancel(String requestId) async {
    cancels++;
    if (cancelPaused != null) {
      if (paused != null && !paused!.isCompleted) {
        paused!.complete('late inside cancellation');
      }
      await cancelPaused!.future;
    }
  }

  @override
  Future<void> unload() async {
    unloads++;
  }
}

void main() {
  late Directory root;
  late ModelConfig config;
  late TestBackend backend;
  late ManagedModelRuntime runtime;
  GenerationRequest request([String id = 'request']) => GenerationRequest(
    requestId: id,
    prompt: 'test only',
    promptTokens: 2,
    maxTokens: 4,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('siraj-b09-model-');
    final bytes = [71, 71, 85, 70, 3, 0, 0, 0, ...List.filled(16, 0)];
    await File('${root.path}/test.gguf').writeAsBytes(bytes);
    config = ModelConfig(
      modelId: 'test-model',
      modelVersion: 'test-version',
      runtimeId: 'test-runtime',
      artifactRoot: root,
      relativePath: 'test.gguf',
      sha256: (await Sha256().hash(
        bytes,
      )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      sizeBytes: bytes.length,
      contextLength: 32,
      promptProfileId: 'test-profile',
    );
    backend = TestBackend();
    runtime = ManagedModelRuntime(
      backend: backend,
      operationTimeout: const Duration(seconds: 1),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Future<void> load() => runtime.load(config, TutorCancellation());
  test(
    'verified GGUF load, generation and explicit unload follow lifecycle',
    () async {
      expect(runtime.state, ModelRuntimeState.notLoaded);
      await load();
      expect(runtime.state, ModelRuntimeState.ready);
      expect(
        await runtime.generate(request(), TutorCancellation()),
        'synthetic test output',
      );
      expect(runtime.state, ModelRuntimeState.ready);
      await runtime.unload();
      expect(runtime.state, ModelRuntimeState.notLoaded);
      expect(backend.unloads, 1);
    },
  );
  test('incorrect hash is rejected before backend load', () async {
    await File('${root.path}/test.gguf').writeAsBytes(List.filled(24, 0));
    await expectLater(load(), throwsA(isA<RuntimeFailure>()));
    expect(backend.loads, 0);
    expect(runtime.state, ModelRuntimeState.error);
  });
  test('not loaded and context overflow never invoke generation', () async {
    await expectLater(
      runtime.generate(request(), TutorCancellation()),
      throwsA(isA<RuntimeFailure>()),
    );
    await load();
    await expectLater(
      runtime.generate(
        GenerationRequest(
          requestId: 'large',
          prompt: 'large',
          promptTokens: 31,
          maxTokens: 4,
        ),
        TutorCancellation(),
      ),
      throwsA(isA<RuntimeFailure>()),
    );
    expect(backend.generations, 0);
  });
  test(
    'cancel settles caller but retains lane until actual backend drainage',
    () async {
      await load();
      backend.paused = Completer<String>();
      final token = TutorCancellation();
      final pending = runtime.generate(request(), token);
      final cancelled = expectLater(
        pending,
        throwsA(
          isA<RuntimeFailure>().having(
            (e) => e.code,
            'code',
            RuntimeErrorCode.cancelled,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await cancelled;
      await expectLater(
        runtime.unload(),
        throwsA(
          isA<RuntimeFailure>().having(
            (e) => e.code,
            'code',
            RuntimeErrorCode.busy,
          ),
        ),
      );
      await expectLater(
        runtime.generate(request('new'), TutorCancellation()),
        throwsA(isA<RuntimeFailure>()),
      );
      expect(backend.unloads, 0);
      expect(backend.generations, 1);
      backend.paused!.complete('late output');
      await runtime.whenIdle;
      await runtime.unload();
      await load();
      expect(runtime.state, ModelRuntimeState.ready);
    },
  );
  test('timeout does not unload a backend still using its model', () async {
    runtime = ManagedModelRuntime(
      backend: backend,
      operationTimeout: const Duration(seconds: 2),
    );
    await load();
    backend.paused = Completer<String>();
    await expectLater(
      runtime.generate(request(), TutorCancellation()),
      throwsA(
        isA<RuntimeFailure>().having(
          (e) => e.code,
          'code',
          RuntimeErrorCode.timeout,
        ),
      ),
    );
    expect(runtime.state, ModelRuntimeState.error);
    await expectLater(runtime.unload(), throwsA(isA<RuntimeFailure>()));
    backend.paused!.complete('late');
    await runtime.whenIdle;
    await runtime.unload();
    expect(backend.unloads, 1);
  });
  test(
    'OOM remains a typed runtime failure and requires explicit recovery',
    () async {
      await load();
      backend.failure = const RuntimeFailure(RuntimeErrorCode.outOfMemory);
      await expectLater(
        runtime.generate(request(), TutorCancellation()),
        throwsA(
          isA<RuntimeFailure>().having(
            (e) => e.code,
            'code',
            RuntimeErrorCode.outOfMemory,
          ),
        ),
      );
      expect(runtime.state, ModelRuntimeState.error);
      await runtime.unload();
      backend.failure = null;
      await load();
      expect(
        await runtime.generate(request(), TutorCancellation()),
        isNotEmpty,
      );
    },
  );
  test(
    'cancelled load cannot become READY or free memory before native completion',
    () async {
      backend.loadPaused = Completer<void>();
      final token = TutorCancellation();
      final loading = runtime.load(config, token);
      final failure = expectLater(
        loading,
        throwsA(
          isA<RuntimeFailure>().having(
            (e) => e.code,
            'code',
            RuntimeErrorCode.cancelled,
          ),
        ),
      );
      for (var i = 0; i < 200 && backend.loads == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(backend.loads, 1);
      token.cancel();
      await failure;
      await expectLater(runtime.unload(), throwsA(isA<RuntimeFailure>()));
      expect(backend.unloads, 0);
      backend.loadPaused!.complete();
      await runtime.whenIdle;
      expect(runtime.state, ModelRuntimeState.error);
      await runtime.unload();
      expect(runtime.state, ModelRuntimeState.notLoaded);
    },
  );
  test('mismatched runtime capabilities never become READY', () async {
    backend.overrideCapabilities = const ModelCapabilities(
      runtimeId: 'wrong',
      contextLength: 32,
      supportsCancellation: false,
    );
    await expectLater(
      load(),
      throwsA(
        isA<RuntimeFailure>().having(
          (e) => e.code,
          'code',
          RuntimeErrorCode.incompatible,
        ),
      ),
    );
    expect(runtime.state, ModelRuntimeState.error);
    await runtime.unload();
  });
  test('already cancelled load never touches backend', () async {
    final token = TutorCancellation()..cancel();
    await expectLater(
      runtime.load(config, token),
      throwsA(isA<RuntimeFailure>()),
    );
    expect(backend.loads, 0);
    expect(runtime.state, ModelRuntimeState.notLoaded);
  });
  test('explicit cancel is request scoped and dispatches once', () async {
    await load();
    backend.paused = Completer<String>();
    final pending = runtime.generate(request(), TutorCancellation());
    final failure = expectLater(
      pending,
      throwsA(
        isA<RuntimeFailure>().having(
          (e) => e.code,
          'code',
          RuntimeErrorCode.cancelled,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await runtime.cancel('other');
    expect(backend.cancels, 0);
    await runtime.cancel('request');
    await runtime.cancel('request');
    await failure;
    backend.paused!.complete('late');
    await runtime.whenIdle;
    expect(backend.cancels, 1);
  });
  test(
    'metrics report successful wall times without fabricated native RAM',
    () async {
      expect(runtime.getMetrics().loadMs, null);
      await load();
      await runtime.generate(request(), TutorCancellation());
      expect(runtime.getMetrics().loadMs, isNonNegative);
      expect(runtime.getMetrics().completionMs, isNonNegative);
      expect(runtime.getMetrics().peakRamBytes, null);
    },
  );
  test(
    'logical cancel settles even when generation is done but backend cancel is stuck',
    () async {
      await load();
      backend.cancelPaused = Completer<void>();
      backend.paused = Completer<String>();
      final token = TutorCancellation();
      var settled = false;
      Object? failure;
      final pending = runtime
          .generate(request(), token)
          .then<void>(
            (_) {
              settled = true;
            },
            onError: (Object e, StackTrace _) {
              settled = true;
              failure = e;
            },
          );
      token.cancel();
      try {
        await Future<void>.delayed(Duration.zero);
        expect(settled, true);
        expect(
          failure,
          isA<RuntimeFailure>().having(
            (e) => e.code,
            'code',
            RuntimeErrorCode.cancelled,
          ),
        );
        await expectLater(
          runtime.unload(),
          throwsA(
            isA<RuntimeFailure>().having(
              (e) => e.code,
              'code',
              RuntimeErrorCode.busy,
            ),
          ),
        );
      } finally {
        backend.cancelPaused!.complete();
        await pending;
        await runtime.whenIdle;
      }
    },
  );
}
