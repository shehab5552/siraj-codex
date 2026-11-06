import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/ai_runtime/ai_runtime_client.dart';
import 'package:siraj/features/ai_runtime/method_channel_ai_runtime_client.dart';
import 'support/native_terminal_watch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('b08-runtime-contract-test');
  late StreamController<Object?> events;
  late MethodChannelAiRuntimeClient client;
  late List<String> methods;
  late Object? vector;
  setUp(() {
    events = StreamController<Object?>.broadcast(sync: true);
    methods = [];
    vector = List<double>.generate(768, (i) => i == 0 ? 1 : 0);
    var serial = 0;
    client = MethodChannelAiRuntimeClient(
      methods: channel,
      events: events.stream,
      newId: () => 'request-${serial++}',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'getRuntimeStatus') {
            return {
              'declaredRuntimeVersion': '0.19.0',
              'abi': 'x86_64',
              'jniLoaded': true,
              'llmInitialized': false,
              'embeddingInitialized': false,
            };
          }
          if (call.method == 'embed') {
            return {'vector': vector, 'elapsedMs': 2.0};
          }
          return {'accepted': true, 'initialized': true};
        });
  });
  tearDown(() async {
    await client.dispose();
    await events.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  void event(String id, String type, int sequence, [String? text]) =>
      events.add({
        'requestId': id,
        'type': type,
        'sequence': sequence,
        'text': ?text,
      });
  Matcher failure(AiRuntimeErrorCode code) =>
      isA<AiRuntimeFailure>().having((e) => e.code, 'typed code', code);
  test('typed actual status contract', () async {
    expect((await client.status()).jniLoaded, isTrue);
  });
  test('ordered chunks, terminal exactly once, stale ignored', () async {
    final run = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final received = run.events.toList();
    event('old', 'generationChunk', 100, 'old');
    event(run.requestId, 'generationStarted', 0);
    event(run.requestId, 'generationChunk', 1, 'actual text');
    event(run.requestId, 'generationCompleted', 2);
    event(run.requestId, 'generationCompleted', 3);
    expect((await received).map((e) => e.type), [
      AiGenerationEventType.started,
      AiGenerationEventType.chunk,
      AiGenerationEventType.completed,
    ]);
  });
  test('concurrent generation rejected', () async {
    await client.generate(systemInstruction: 'system', input: 'input');
    await expectLater(
      client.generate(systemInstruction: 'system', input: 'input'),
      throwsA(failure(AiRuntimeErrorCode.busy)),
    );
  });
  test('cancel prevents stale events reaching next run', () async {
    final first = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final received = first.events.toList();
    event(first.requestId, 'generationStarted', 0);
    await first.cancel();
    await expectLater(
      client.generate(
        systemInstruction: 'system',
        input: 'still native active',
      ),
      throwsA(failure(AiRuntimeErrorCode.busy)),
    );
    event(first.requestId, 'generationCancelled', 1);
    expect((await received).last.type, AiGenerationEventType.cancelled);
    final second = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final output = second.events.toList();
    event(first.requestId, 'generationCompleted', 0);
    event(second.requestId, 'generationStarted', 0);
    event(second.requestId, 'generationCompleted', 1);
    expect((await output).length, 2);
  });
  test('malformed current event fails closed and cancels native', () async {
    final run = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final received = run.events.toList();
    event(run.requestId, 'generationChunk', 7, 'gap');
    expect((await received).single.error, AiRuntimeErrorCode.protocolViolation);
    await Future<void>.delayed(Duration.zero);
    expect(methods, contains('cancelGeneration'));
    await expectLater(
      client.generate(systemInstruction: 'system', input: 'next'),
      throwsA(failure(AiRuntimeErrorCode.channelUnavailable)),
    );
  });
  test(
    'cancel acceptance is not terminal; duplicate requests share call',
    () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = <AiGenerationEvent>[];
      final subscription = run.events.listen(received.add);
      event(run.requestId, 'generationStarted', 0);
      await Future.wait([run.cancel(), run.cancel()]);
      await Future<void>.delayed(Duration.zero);
      expect(received.map((e) => e.type), [AiGenerationEventType.started]);
      expect(methods.where((m) => m == 'cancelGeneration').length, 1);
      await expectLater(
        client.generate(systemInstruction: 'system', input: 'next'),
        throwsA(failure(AiRuntimeErrorCode.busy)),
      );
      event(run.requestId, 'generationCancelled', 1);
      event(run.requestId, 'generationCancelled', 2);
      await Future<void>.delayed(Duration.zero);
      expect(received.map((e) => e.type), [
        AiGenerationEventType.started,
        AiGenerationEventType.cancelled,
      ]);
      await subscription.cancel();
    },
  );
  for (final terminal in ['generationCompleted', 'generationFailed']) {
    test('cancel followed by $terminal preserves Native outcome', () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = run.events.toList();
      event(run.requestId, 'generationStarted', 0);
      await run.cancel();
      events.add({
        'requestId': run.requestId,
        'type': terminal,
        'sequence': 1,
        'code': 'generationFailed',
      });
      expect(
        (await received).last.type,
        terminal == 'generationCompleted'
            ? AiGenerationEventType.completed
            : AiGenerationEventType.failed,
      );
    });
  }
  test(
    'cancel exception stays sanitized and busy until Native terminal',
    () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = run.events.toList();
      event(run.requestId, 'generationStarted', 0);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'cancelGeneration') {
              throw PlatformException(
                code: 'cancelFailed',
                message: 'private path and prompt',
              );
            }
            return null;
          });
      await expectLater(
        run.cancel(),
        throwsA(failure(AiRuntimeErrorCode.cancelFailed)),
      );
      await expectLater(
        run.cancel(),
        throwsA(failure(AiRuntimeErrorCode.cancelFailed)),
      );
      expect(methods.where((m) => m == 'cancelGeneration').length, 1);
      await expectLater(
        client.generate(systemInstruction: 'system', input: 'next'),
        throwsA(failure(AiRuntimeErrorCode.busy)),
      );
      events.add({
        'requestId': run.requestId,
        'type': 'generationFailed',
        'sequence': 1,
        'code': 'cancelFailed',
      });
      final result = await received;
      expect(result.last.error, AiRuntimeErrorCode.cancelFailed);
      expect(
        result.any((e) => e.type == AiGenerationEventType.cancelled),
        isFalse,
      );
    },
  );
  test(
    'terminal inside cancel method reply is observable exactly once',
    () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = run.events.toList();
      event(run.requestId, 'generationStarted', 0);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelGeneration') {
              event(run.requestId, 'generationCancelled', 1);
            }
            return null;
          });
      await run.cancel();
      expect(
        (await received)
            .where((e) => e.type == AiGenerationEventType.cancelled)
            .length,
        1,
      );
    },
  );
  test(
    'dispose during cancel drains Native close without false local terminal',
    () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = <AiGenerationEvent>[];
      final subscription = run.events.listen(received.add);
      event(run.requestId, 'generationStarted', 0);
      await run.cancel();
      final closeEntered = Completer<void>(), releaseClose = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'closeLlm') {
              closeEntered.complete();
              await releaseClose.future;
            }
            return null;
          });
      var disposed = false;
      final disposal = client.dispose().then((_) => disposed = true);
      await closeEntered.future;
      expect(disposed, isFalse);
      expect(
        received.any((e) => e.type == AiGenerationEventType.cancelled),
        isFalse,
      );
      event(run.requestId, 'generationCancelled', 1);
      releaseClose.complete();
      await disposal;
      expect(received.last.type, AiGenerationEventType.cancelled);
      expect(methods, contains('closeEmbedding'));
      await subscription.cancel();
    },
  );
  test(
    'dispose after rejected cancel still closes both handles; no fake cancellation',
    () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = run.events.toList();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'cancelGeneration') {
              throw PlatformException(code: 'cancelFailed');
            }
            return null;
          });
      await expectLater(
        run.cancel(),
        throwsA(failure(AiRuntimeErrorCode.cancelFailed)),
      );
      await client.dispose();
      expect((await received).single.error, AiRuntimeErrorCode.disposed);
      expect(methods, containsAll(['closeLlm', 'closeEmbedding']));
    },
  );
  test(
    'embedding failed-close status and typed error survive transport',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getRuntimeStatus') {
              return {
                'declaredRuntimeVersion': '0.19.0',
                'abi': 'x86_64',
                'jniLoaded': true,
                'llmInitialized': false,
                'embeddingInitialized': true,
                'embeddingQuarantined': true,
              };
            }
            throw PlatformException(
              code: 'embeddingCloseFailed',
              details: 'private SDK details',
            );
          });
      final status = await client.status();
      expect(status.embeddingLoaded, isTrue);
      expect(status.embeddingQuarantined, isTrue);
      await expectLater(
        client.closeEmbedding(),
        throwsA(failure(AiRuntimeErrorCode.embeddingCloseFailed)),
      );
      await expectLater(
        client.embed('query'),
        throwsA(failure(AiRuntimeErrorCode.embeddingCloseFailed)),
      );
    },
  );
  test('missing plugin sanitized', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await expectLater(
      client.status(),
      throwsA(failure(AiRuntimeErrorCode.channelUnavailable)),
    );
  });
  test('platform exception details never escape', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'initializationFailed',
            message: 'private native path',
            details: 'private prompt',
          ),
        );
    await expectLater(
      client.initializeLlm('approved-key'),
      throwsA(failure(AiRuntimeErrorCode.initializationFailed)),
    );
  });
  test('embedding typed finite dimension', () async {
    expect((await client.embed('query')).values.length, 768);
  });
  test('embedding wrong dimension', () async {
    vector = [1.0];
    await expectLater(
      client.embed('query'),
      throwsA(failure(AiRuntimeErrorCode.embeddingDimension)),
    );
  });
  test('embedding non finite', () async {
    vector = List<double>.filled(768, double.nan);
    await expectLater(
      client.embed('query'),
      throwsA(failure(AiRuntimeErrorCode.nonFiniteEmbedding)),
    );
  });
  test('embedding zero', () async {
    vector = List<double>.filled(768, 0);
    await expectLater(
      client.embed('query'),
      throwsA(failure(AiRuntimeErrorCode.zeroEmbedding)),
    );
  });
  test(
    'closed event stream cancels native and fails future calls promptly',
    () async {
      final run = await client.generate(
        systemInstruction: 'system',
        input: 'input',
      );
      final received = run.events.toList();
      await events.close();
      expect(
        (await received).single.error,
        AiRuntimeErrorCode.channelUnavailable,
      );
      await Future<void>.delayed(Duration.zero);
      expect(methods, contains('cancelGeneration'));
      await expectLater(
        client.generate(systemInstruction: 'system', input: 'next'),
        throwsA(failure(AiRuntimeErrorCode.channelUnavailable)),
      );
    },
  );
  test('event channel error cancels abandoned native request', () async {
    final run = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final received = run.events.toList();
    events.addError(StateError('private native details'));
    expect(
      (await received).single.error,
      AiRuntimeErrorCode.channelUnavailable,
    );
    await Future<void>.delayed(Duration.zero);
    expect(methods, contains('cancelGeneration'));
  });
  test('chunks and terminal before method reply remain observable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'generate') {
            final id = (call.arguments as Map)['requestId'] as String;
            event(id, 'generationStarted', 0);
            event(id, 'generationChunk', 1, 'test-only native delta');
            event(id, 'generationCompleted', 2);
          }
          return {'accepted': true};
        });
    final terminal = observeNativeTerminal(events.stream, 'request-0');
    final run = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    expect((await terminal)['type'], 'generationCompleted');
    final received = await run.events.toList();
    expect(received.last.type, AiGenerationEventType.completed);
    await run.cancel();
    expect(methods.where((method) => method == 'cancelGeneration'), isEmpty);
  });
  test('actual SDK counters are optional typed generation evidence', () async {
    final run = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final received = run.events.toList();
    event(run.requestId, 'generationStarted', 0);
    events.add({
      'requestId': run.requestId,
      'type': 'generationCompleted',
      'sequence': 1,
      'benchmark': {
        'initializeSeconds': 1.0,
        'firstTokenSeconds': 0.2,
        'prefillTokens': 10,
        'decodeTokens': 4,
        'prefillTokensPerSecond': 50.0,
        'decodeTokensPerSecond': 8.0,
      },
    });
    final terminal = (await received).last;
    expect(terminal.benchmark!.decodeTokens, 4);
  });
  test('invalid benchmark numbers are never exposed as measurements', () async {
    final run = await client.generate(
      systemInstruction: 'system',
      input: 'input',
    );
    final received = run.events.toList();
    event(run.requestId, 'generationStarted', 0);
    events.add({
      'requestId': run.requestId,
      'type': 'generationCompleted',
      'sequence': 1,
      'benchmark': {
        'initializeSeconds': 1.0,
        'firstTokenSeconds': double.nan,
        'prefillTokens': 10,
        'decodeTokens': 4,
        'prefillTokensPerSecond': 50.0,
        'decodeTokensPerSecond': 8.0,
      },
    });
    expect((await received).last.benchmark, isNull);
  });
  test('disposed client rejects new work', () async {
    await client.dispose();
    await expectLater(
      client.status(),
      throwsA(failure(AiRuntimeErrorCode.disposed)),
    );
  });
}
