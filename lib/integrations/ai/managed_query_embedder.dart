import 'package:uuid/uuid.dart';
import '../../features/resources/artifact_integrity_validator.dart';
import '../../features/resources/resource_validation_contracts.dart';
import 'rag_runtime_contract.dart';
import 'runtime_contract.dart';
import 'runtime_operation_lane.dart';
import 'shared_embedding_runtime_contract.dart';
import 'tutor_contract.dart';

/// One immutable shared embedding configuration for one revision. Its ready
/// state is operational only, never product RAG_READY or Android acceptance.
class ManagedQueryEmbedder implements QueryEmbedder {
  ManagedQueryEmbedder({
    required SharedEmbeddingConfig config,
    EmbeddingBackend backend = const UnavailableEmbeddingBackend(),
    required Duration operationTimeout,
    String Function()? newId,
  }) : _config = config,
       _backend = backend,
       _operations = RuntimeOperationLane(operationTimeout),
       _newId = newId ?? Uuid().v4;
  final SharedEmbeddingConfig _config;
  final EmbeddingBackend _backend;
  final RuntimeOperationLane _operations;
  final String Function() _newId;
  EmbeddingRuntimeState _state = EmbeddingRuntimeState.notLoaded;
  EmbeddingCapabilities? _capabilities;
  bool _nativeLoadStarted = false;
  int? _loadMs, _completionMs;
  EmbeddingRuntimeState get state => _state;
  @override
  EmbeddingBinding get configuration => _config.binding;
  Future<void> get whenIdle => _operations.whenIdle;
  RuntimeMetrics getMetrics() =>
      RuntimeMetrics(loadMs: _loadMs, completionMs: _completionMs);
  void _check(TutorCancellation token) {
    if (token.isCancelled) {
      throw const RuntimeFailure(RuntimeErrorCode.cancelled);
    }
  }

  Future<T> _perform<T>(
    EmbeddingRuntimeState phase,
    TutorCancellation cancellation,
    Future<T> Function(TutorCancellation) work, {
    String? requestId,
    required RuntimeErrorCode failureCode,
    required EmbeddingRuntimeState successState,
  }) async {
    _operations.requireIdle();
    _check(cancellation);
    _state = phase;
    final clock = Stopwatch()..start();
    try {
      final value = await _operations.run<T>(
        external: cancellation,
        work: work,
        requestId: requestId,
        onCancel:
            requestId != null && _capabilities?.supportsCancellation == true
            ? () => _backend.cancel(requestId)
            : null,
        onSuccess: (_) {
          _state = successState;
          if (phase == EmbeddingRuntimeState.loading) {
            _loadMs = clock.elapsedMilliseconds;
          }
          if (phase == EmbeddingRuntimeState.embedding) {
            _completionMs = clock.elapsedMilliseconds;
          }
        },
        onFailure: (_) {
          _state = EmbeddingRuntimeState.error;
        },
      );
      return value;
    } catch (e) {
      if (e is RuntimeFailure) rethrow;
      throw RuntimeFailure(failureCode);
    }
  }

  Future<void> load(TutorCancellation cancellation) async {
    _operations.requireIdle();
    if (_state != EmbeddingRuntimeState.notLoaded) {
      throw const RuntimeFailure(RuntimeErrorCode.notReady);
    }
    await _perform<void>(
      EmbeddingRuntimeState.loading,
      cancellation,
      (token) async {
        final files = _config.artifacts;
        if (!configuration.isValid ||
            !validIdentity(_config.runtimeId) ||
            files.isEmpty ||
            files.map((f) => f.relativePath).toSet().length != files.length ||
            !files.any(
              (f) => f.relativePath == configuration.artifactRelativePath,
            ) ||
            files.any((f) => f.sizeBytes <= 0)) {
          throw const RuntimeFailure(RuntimeErrorCode.incompatible);
        }
        for (final file in files) {
          _check(token);
          final result = await const ArtifactIntegrityValidator().validate(
            stagingRoot: _config.artifactRoot,
            relativePath: file.relativePath,
            kind: ResourceContractKind.ragEmbedding,
            expectedSizeBytes: file.sizeBytes,
            expectedSha256: file.sha256,
          );
          if (result is! ArtifactIntegrityMatch) {
            throw const RuntimeFailure(RuntimeErrorCode.incompatible);
          }
        }
        _check(token);
        _nativeLoadStarted = true;
        final caps = await _backend.load(_config, token);
        if (caps.runtimeId != _config.runtimeId ||
            caps.binding != configuration) {
          throw const RuntimeFailure(RuntimeErrorCode.incompatible);
        }
        _check(token);
        _capabilities = caps;
      },
      failureCode: RuntimeErrorCode.loadFailed,
      successState: EmbeddingRuntimeState.ready,
    );
  }

  @override
  Future<List<double>> embed(
    String text,
    TutorCancellation cancellation,
  ) async {
    _operations.requireIdle();
    if (_state != EmbeddingRuntimeState.ready || _capabilities == null) {
      throw const RuntimeFailure(RuntimeErrorCode.notReady);
    }
    if (text.trim().isEmpty) {
      throw const RuntimeFailure(RuntimeErrorCode.incompatible);
    }
    final id = _newId();
    if (!validIdentity(id)) {
      throw const RuntimeFailure(RuntimeErrorCode.incompatible);
    }
    return _perform<List<double>>(
      EmbeddingRuntimeState.embedding,
      cancellation,
      (token) async {
        final output = await _backend.embed(
          EmbeddingRequest(requestId: id, text: text),
          token,
        );
        _check(token);
        if (output.length != configuration.dimension ||
            output.any((v) => !v.isFinite)) {
          throw const RuntimeFailure(RuntimeErrorCode.invalidOutput);
        }
        return List<double>.unmodifiable(output);
      },
      requestId: id,
      failureCode: RuntimeErrorCode.embeddingFailed,
      successState: EmbeddingRuntimeState.ready,
    );
  }

  Future<void> unload() async {
    _operations.requireIdle();
    if (_state == EmbeddingRuntimeState.notLoaded) return;
    await _perform<void>(
      EmbeddingRuntimeState.notLoaded,
      TutorCancellation(),
      (_) async {
        if (_nativeLoadStarted) await _backend.unload();
        _nativeLoadStarted = false;
        _capabilities = null;
      },
      failureCode: RuntimeErrorCode.loadFailed,
      successState: EmbeddingRuntimeState.notLoaded,
    );
  }
}
