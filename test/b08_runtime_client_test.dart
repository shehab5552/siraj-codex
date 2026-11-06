import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/ai_runtime/ai_runtime_client.dart';
import 'package:siraj/features/ai_runtime/method_channel_ai_runtime_client.dart';

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
    await first.cancel();
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
  });
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
  test('disposed client rejects new work', () async {
    await client.dispose();
    await expectLater(
      client.status(),
      throwsA(failure(AiRuntimeErrorCode.disposed)),
    );
  });
}
