import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'ai_runtime_client.dart';

/// One shared client owns the versioned native event subscription. No Widgets,
/// filesystem paths, scientific defaults or persistence live at this boundary.
class MethodChannelAiRuntimeClient implements AiRuntimeClient {
  MethodChannelAiRuntimeClient({
    MethodChannel? methods,
    Stream<Object?>? events,
    String Function()? newId,
  }) : _methods = methods ?? const MethodChannel('siraj/ai_runtime/methods_v1'),
       _events =
           events ??
           const EventChannel(
             'siraj/ai_runtime/events_v1',
           ).receiveBroadcastStream(),
       _newId = newId ?? const Uuid().v4;
  final MethodChannel _methods;
  final Stream<Object?> _events;
  final String Function() _newId;
  StreamSubscription<Object?>? _subscription;
  _Run? _active;
  bool _disposed = false;
  bool _eventsLost = false;
  Future<void>? _disposing;
  void _check() {
    if (_disposed) throw const AiRuntimeFailure(AiRuntimeErrorCode.disposed);
  }

  static AiRuntimeErrorCode _code(Object? raw) =>
      AiRuntimeErrorCode.values.firstWhere(
        (c) => c.name == raw,
        orElse: () => AiRuntimeErrorCode.generationFailed,
      );
  Future<Object?> _invoke(String name, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<Object?>(name, args);
    } on MissingPluginException {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.channelUnavailable);
    } on PlatformException catch (e) {
      throw AiRuntimeFailure(_code(e.code));
    }
  }

  @override
  Future<AiRuntimeStatus> status() async {
    _check();
    final value = await _invoke('getRuntimeStatus');
    if (value is! Map ||
        value['declaredRuntimeVersion'] is! String ||
        value['abi'] is! String ||
        value['jniLoaded'] is! bool ||
        value['llmInitialized'] is! bool ||
        value['embeddingInitialized'] is! bool) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.protocolViolation);
    }
    return AiRuntimeStatus(
      version: value['declaredRuntimeVersion'] as String,
      abi: value['abi'] as String,
      jniLoaded: value['jniLoaded'] as bool,
      llmLoaded: value['llmInitialized'] as bool,
      embeddingLoaded: value['embeddingInitialized'] as bool,
    );
  }

  Future<void> _initialize(String method, String resourceId) async {
    _check();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(resourceId)) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.invalidRequest);
    }
    final value = await _invoke(method, {'resourceId': resourceId});
    if (value is! Map || value['initialized'] != true) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.protocolViolation);
    }
  }

  @override
  Future<void> initializeLlm(String resourceId) =>
      _initialize('initializeLlm', resourceId);
  @override
  Future<void> initializeEmbedding(String resourceId) =>
      _initialize('initializeEmbedding', resourceId);
  @override
  Future<AiGeneration> generate({
    required String systemInstruction,
    required String input,
  }) async {
    _check();
    if (_eventsLost) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.channelUnavailable);
    }
    if (_active != null) throw const AiRuntimeFailure(AiRuntimeErrorCode.busy);
    if (input.trim().isEmpty ||
        systemInstruction.trim().isEmpty ||
        input.length > 32768 ||
        systemInstruction.length > 32768) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.invalidRequest);
    }
    _subscription ??= _events.listen(
      _event,
      onError: (Object error, StackTrace stack) => _loseEvents(),
      onDone: _loseEvents,
    );
    final run = _Run(_newId());
    _active = run;
    try {
      final result = await _invoke('generate', {
        'requestId': run.id,
        'systemInstruction': systemInstruction,
        'input': input,
      });
      if (result is! Map || result['accepted'] != true) {
        throw const AiRuntimeFailure(AiRuntimeErrorCode.protocolViolation);
      }
    } catch (_) {
      if (identical(_active, run)) _active = null;
      unawaited(run.controller.close());
      rethrow;
    }
    return AiGeneration(run.id, run.controller.stream, () => _cancel(run));
  }

  void _loseEvents() {
    _eventsLost = true;
    final run = _active;
    if (run != null) {
      _terminate(
        run,
        const AiGenerationEvent(
          AiGenerationEventType.failed,
          error: AiRuntimeErrorCode.channelUnavailable,
        ),
      );
      unawaited(_cancelNative(run.id));
    }
    // A dead platform transport requires owner disposal and a new client.
    // Never silently accept work on a permanently ended subscription.
  }

  void _event(Object? raw) {
    final run = _active;
    if (run == null || raw is! Map || raw['requestId'] != run.id) return;
    final kind = raw['type'];
    if (raw['sequence'] != run.sequence ||
        (run.sequence == 0 && kind != 'generationStarted')) {
      _protocol(run);
      return;
    }
    run.sequence++;
    switch (kind) {
      case 'generationStarted':
        if (run.sequence != 1) {
          _protocol(run);
          return;
        }
        run.controller.add(
          const AiGenerationEvent(AiGenerationEventType.started),
        );
      case 'generationChunk':
        final text = raw['text'];
        if (text is! String || text.length + run.characters > 262144) {
          _protocol(run);
          return;
        }
        run.characters += text.length;
        run.controller.add(
          AiGenerationEvent(AiGenerationEventType.chunk, text: text),
        );
      case 'generationCompleted':
        _terminate(
          run,
          const AiGenerationEvent(AiGenerationEventType.completed),
        );
      case 'generationCancelled':
        _terminate(
          run,
          const AiGenerationEvent(AiGenerationEventType.cancelled),
        );
      case 'generationFailed':
        _terminate(
          run,
          AiGenerationEvent(
            AiGenerationEventType.failed,
            error: _code(raw['code']),
          ),
        );
      default:
        _protocol(run);
    }
  }

  void _terminate(_Run run, AiGenerationEvent terminal) {
    if (!identical(_active, run)) return;
    _active = null;
    run.controller.add(terminal);
    unawaited(run.controller.close());
  }

  void _protocol(_Run run) {
    _terminate(
      run,
      const AiGenerationEvent(
        AiGenerationEventType.failed,
        error: AiRuntimeErrorCode.protocolViolation,
      ),
    );
    unawaited(_cancelNative(run.id));
  }

  Future<void> _cancelNative(String id) async {
    try {
      await _invoke('cancelGeneration', {'requestId': id});
    } on AiRuntimeFailure {
      /* Already locally terminated; never emit a second terminal. */
    }
  }

  Future<void> _cancel(_Run run) async {
    if (!identical(_active, run)) return;
    _terminate(run, const AiGenerationEvent(AiGenerationEventType.cancelled));
    await _cancelNative(run.id);
  }

  @override
  Future<AiEmbedding> embed(String input) async {
    _check();
    if (input.trim().isEmpty || input.length > 32768) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.invalidRequest);
    }
    final result = await _invoke('embed', {'input': input});
    if (result is! Map ||
        result['vector'] is! List ||
        result['elapsedMs'] is! num) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.protocolViolation);
    }
    final raw = result['vector'] as List;
    if (raw.length != 768) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.embeddingDimension);
    }
    if (raw.any((x) => x is! num || !x.isFinite)) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.nonFiniteEmbedding);
    }
    final values = raw
        .cast<num>()
        .map((v) => v.toDouble())
        .toList(growable: false);
    if (values.every((v) => v == 0)) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.zeroEmbedding);
    }
    final elapsed = (result['elapsedMs'] as num).toDouble();
    if (!elapsed.isFinite || elapsed < 0) {
      throw const AiRuntimeFailure(AiRuntimeErrorCode.protocolViolation);
    }
    return AiEmbedding(values, elapsed);
  }

  @override
  Future<void> closeLlm() async {
    _check();
    final run = _active;
    if (run != null) await _cancel(run);
    await _invoke('closeLlm');
  }

  @override
  Future<void> closeEmbedding() async {
    _check();
    await _invoke('closeEmbedding');
  }

  @override
  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    final run = _active;
    if (run != null) await _cancel(run);
    for (final method in ['closeLlm', 'closeEmbedding']) {
      try {
        await _invoke(method);
      } on AiRuntimeFailure {
        /* Native absent or activity already disposed. */
      }
    }
    await _subscription?.cancel();
    _subscription = null;
  }
}

class _Run {
  _Run(this.id);
  final String id;
  final controller = StreamController<AiGenerationEvent>();
  int sequence = 0, characters = 0;
}
