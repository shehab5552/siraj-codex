import '../../features/resources/artifact_integrity_validator.dart';
import '../../features/resources/resource_format_preflight.dart';
import '../../features/resources/resource_validation_contracts.dart';
import 'runtime_contract.dart';
import 'runtime_operation_lane.dart';
import 'tutor_contract.dart';

/// Owns one native backend lane. A timeout/cancel never authorizes concurrent
/// reuse/freeing of model memory. Its immutable file lease belongs to the caller
/// until unload succeeds. No runtime build, model or work-factor is approved here.
class ManagedModelRuntime implements ModelRuntime {
  ManagedModelRuntime({
    required ModelBackend backend,
    required Duration operationTimeout,
  }) : _backend = backend,
       _operations = RuntimeOperationLane(operationTimeout) {
    if (operationTimeout <= Duration.zero) {
      throw ArgumentError.value(operationTimeout);
    }
  }
  final ModelBackend _backend;
  final RuntimeOperationLane _operations;
  ModelRuntimeState _state = ModelRuntimeState.notLoaded;
  ModelConfig? _configuration;
  ModelCapabilities? _capabilities;
  int? _loadMs, _completionMs;
  @override
  RuntimeMetrics getMetrics() =>
      RuntimeMetrics(loadMs: _loadMs, completionMs: _completionMs);
  @override
  ModelRuntimeState get state => _state;
  @override
  ModelConfig? get configuration => _configuration;
  @override
  ModelCapabilities? get capabilities => _capabilities;
  @override
  Future<void> get whenIdle => _operations.whenIdle;

  void _requireIdle() {
    _operations.requireIdle();
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
    _state = phase;
    final clock = Stopwatch()..start();
    try {
      final result = await _operations.run<T>(
        external: external,
        work: work,
        requestId: requestId,
        onCancel:
            requestId != null && _capabilities?.supportsCancellation == true
            ? () => _backend.cancel(requestId)
            : null,
        onSuccess: (_) {
          _state = successState;
          if (phase == ModelRuntimeState.loading) {
            _loadMs = clock.elapsedMilliseconds;
          }
          if (phase == ModelRuntimeState.generating) {
            _completionMs = clock.elapsedMilliseconds;
          }
        },
        onFailure: (_) {
          _state = ModelRuntimeState.error;
        },
      );
      return result;
    } catch (error) {
      if (error is RuntimeFailure) rethrow;
      throw RuntimeFailure(failureCode);
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    _operations.cancel(requestId);
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
