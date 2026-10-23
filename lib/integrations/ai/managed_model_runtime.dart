import 'dart:async';

import '../../features/resources/artifact_integrity_validator.dart';
import '../../features/resources/resource_format_preflight.dart';
import '../../features/resources/resource_validation_contracts.dart';
import 'runtime_contract.dart';
import 'tutor_contract.dart';

/// Owns one native backend lane. A timeout/cancel never authorizes concurrent
/// reuse/freeing of model memory. Its immutable file lease belongs to the caller
/// until unload succeeds. No runtime build, model or work-factor is approved here.
class ManagedModelRuntime implements ModelRuntime {
  ManagedModelRuntime({
    required ModelBackend backend,
    required Duration operationTimeout,
  }) : _backend = backend,
       _timeout = operationTimeout {
    if (operationTimeout <= Duration.zero) {
      throw ArgumentError.value(operationTimeout);
    }
  }
  final ModelBackend _backend;
  final Duration _timeout;
  ModelRuntimeState _state = ModelRuntimeState.notLoaded;
  ModelConfig? _configuration;
  ModelCapabilities? _capabilities;
  Future<void>? _lane;
  int? _loadMs, _completionMs;
  @override
  RuntimeMetrics getMetrics() =>
      RuntimeMetrics(loadMs: _loadMs, completionMs: _completionMs);
  TutorCancellation? _activeCancellation;
  String? _activeRequestId;
  @override
  ModelRuntimeState get state => _state;
  @override
  ModelConfig? get configuration => _configuration;
  @override
  ModelCapabilities? get capabilities => _capabilities;
  @override
  Future<void> get whenIdle => _lane ?? Future<void>.value();

  void _requireIdle() {
    if (_lane != null) throw const RuntimeFailure(RuntimeErrorCode.busy);
  }

  @override
  Future<void> load(ModelConfig config, TutorCancellation cancellation) async {
    _requireIdle();
    if (_state != ModelRuntimeState.notLoaded) {
      throw const RuntimeFailure(RuntimeErrorCode.notReady);
    }
    await _perform<void>(
      ModelRuntimeState.loading,
      cancellation,
      (token) async {
        if ([
              config.modelId,
              config.modelVersion,
              config.runtimeId,
              config.promptProfileId,
            ].any((s) => s.trim().isEmpty) ||
            config.contextLength <= 0 ||
            config.sizeBytes <= 0) {
          throw const RuntimeFailure(RuntimeErrorCode.incompatible);
        }
        final artifact = await const ArtifactIntegrityValidator().validate(
          stagingRoot: config.artifactRoot,
          relativePath: config.relativePath,
          kind: ResourceContractKind.llm,
          expectedSha256: config.sha256,
          expectedSizeBytes: config.sizeBytes,
        );
        if (artifact is! ArtifactIntegrityMatch ||
            ResourceFormatPreflight.inspect(artifact).status !=
                FormatHeaderStatus.recognizedHeader) {
          throw const RuntimeFailure(RuntimeErrorCode.incompatible);
        }
        _checkCancelled(token);
        _configuration =
            config; // retain ownership even if a partial native load fails
        final caps = await _backend.load(config, token);
        if (caps.runtimeId != config.runtimeId ||
            caps.contextLength < config.contextLength) {
          throw const RuntimeFailure(RuntimeErrorCode.incompatible);
        }
        _checkCancelled(token);
        _capabilities = caps;
      },
      successState: ModelRuntimeState.ready,
      failureCode: RuntimeErrorCode.loadFailed,
    );
  }

  @override
  Future<String> generate(
    GenerationRequest request,
    TutorCancellation cancellation,
  ) async {
    _requireIdle();
    final config = _configuration;
    if (_state != ModelRuntimeState.ready ||
        config == null ||
        _capabilities == null) {
      throw const RuntimeFailure(RuntimeErrorCode.notReady);
    }
    if (request.requestId.trim().isEmpty ||
        request.prompt.trim().isEmpty ||
        request.promptTokens <= 0 ||
        request.maxTokens <= 0 ||
        request.promptTokens + request.maxTokens > config.contextLength) {
      throw const RuntimeFailure(RuntimeErrorCode.incompatible);
    }
    return _perform<String>(
      ModelRuntimeState.generating,
      cancellation,
      (token) async {
        final output = await _backend.generate(request, token);
        _checkCancelled(token);
        if (output.trim().isEmpty) {
          throw const RuntimeFailure(RuntimeErrorCode.invalidOutput);
        }
        return output;
      },
      requestId: request.requestId,
      successState: ModelRuntimeState.ready,
      failureCode: RuntimeErrorCode.generationFailed,
    );
  }

  void _checkCancelled(TutorCancellation token) {
    if (token.isCancelled) {
      throw const RuntimeFailure(RuntimeErrorCode.cancelled);
    }
  }

  Future<T> _perform<T>(
    ModelRuntimeState phase,
    TutorCancellation external,
    Future<T> Function(TutorCancellation) work, {
    String? requestId,
    required ModelRuntimeState successState,
    required RuntimeErrorCode failureCode,
  }) async {
    _checkCancelled(external);
    final token = TutorCancellation();
    final logicalSettled = Completer<void>();
    final interrupted = Completer<T>();
    Future<void>? cancelDrain;
    var stopped = false;
    void interrupt(RuntimeErrorCode code) {
      if (stopped || logicalSettled.isCompleted) return;
      stopped = true;
      token.cancel();
      if (requestId != null && _capabilities?.supportsCancellation == true) {
        cancelDrain = Future<void>.sync(
          () => _backend.cancel(requestId),
        ).then<void>((_) {}, onError: (Object _, StackTrace _) {});
      }
      interrupted.completeError(RuntimeFailure(code));
    }

    _activeCancellation = token;
    _activeRequestId = requestId;
    _state = phase;
    final clock = Stopwatch()..start();
    external.whenCancelled.then((_) => interrupt(RuntimeErrorCode.cancelled));
    token.whenCancelled.then((_) => interrupt(RuntimeErrorCode.cancelled));
    final timer = Timer(_timeout, () => interrupt(RuntimeErrorCode.timeout));
    final actual = Future<T>.sync(() => work(token));
    var actualDone = false;
    final actualSettled = actual.then<void>(
      (_) {
        actualDone = true;
      },
      onError: (Object _, StackTrace _) {
        actualDone = true;
      },
    );
    late final Future<void> drain;
    drain = () async {
      await actualSettled;
      await logicalSettled.future;
      final cancellation = cancelDrain;
      if (cancellation != null) await cancellation;
      if (identical(_lane, drain)) {
        _lane = null;
        _activeCancellation = null;
        _activeRequestId = null;
      }
    }();
    _lane = drain;
    try {
      final result = await Future.any([actual, interrupted.future]);
      _checkCancelled(token);
      _state = successState;
      if (phase == ModelRuntimeState.loading) {
        _loadMs = clock.elapsedMilliseconds;
      }
      if (phase == ModelRuntimeState.generating) {
        _completionMs = clock.elapsedMilliseconds;
      }
      return result;
    } catch (error) {
      _state = ModelRuntimeState.error;
      if (error is RuntimeFailure) rethrow;
      throw RuntimeFailure(
        failureCode,
      ); // never expose prompt/native exception text
    } finally {
      timer.cancel();
      logicalSettled.complete();
      // An asynchronous native cancel can itself hang after generation stops.
      // Keep that lane occupied, but settle the logical interrupted caller.
      if (actualDone && cancelDrain == null) await drain;
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    if (requestId == _activeRequestId) _activeCancellation?.cancel();
  }

  @override
  Future<void> unload() async {
    _requireIdle();
    if (_state == ModelRuntimeState.notLoaded) return;
    await _perform<void>(
      ModelRuntimeState.notLoaded,
      TutorCancellation(),
      (_) async {
        await _backend.unload();
        _configuration = null;
        _capabilities = null;
      },
      successState: ModelRuntimeState.notLoaded,
      failureCode: RuntimeErrorCode.loadFailed,
    );
  }
}
