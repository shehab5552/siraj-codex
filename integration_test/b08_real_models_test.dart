import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/features/ai_runtime/ai_runtime_client.dart';
import 'package:siraj/features/ai_runtime/method_channel_ai_runtime_client.dart';
import '../test/support/native_terminal_watch.dart';

/// Licensed, owner-pinned files are prepared in the DEBUG private fixture root.
/// No fixture answer is provided. No prompt, generated text or vector is logged.
/// These engineering tests cannot establish Biology G2/G3 or Samsung readiness.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('siraj/ai_runtime/methods_v1');
  final bus = const EventChannel(
    'siraj/ai_runtime/events_v1',
  ).receiveBroadcastStream().asBroadcastStream();
  testWidgets(
    'B08 genuine local embedding and LLM, cancel, reload, offline',
    (tester) async {
      final passed = await tester.runAsync(() async {
        var requestSerial = 0;
        final client = MethodChannelAiRuntimeClient(
          events: bus,
          newId: () => 'b08-model-request-${requestSerial++}',
        );
        final metrics = <String, Object?>{
          'scope': 'X86_64_EMULATOR_ENGINEERING_ONLY',
          'g2': 'BLOCKED',
          'g3': 'BLOCKED',
          'productionResourcesApproved': false,
          'firstTokenLatency': 'NOT MEASURED; text chunks only',
          'tokensPerSecond': 'NOT MEASURED; no exact output token counter',
        };
        int sampledPeakPssKb = 0, maxNativeHeapBytes = 0, samples = 0;
        bool sampling = false;
        Future<void> sample() async {
          if (sampling) return;
          sampling = true;
          try {
            final s = await methods.invokeMapMethod<String, Object?>(
              'getRuntimeStatus',
            );
            sampledPeakPssKb = math.max(
              sampledPeakPssKb,
              (s?['sampledPssKb'] as num).toInt(),
            );
            maxNativeHeapBytes = math.max(
              maxNativeHeapBytes,
              (s?['nativeHeapAllocatedBytes'] as num).toInt(),
            );
            samples++;
          } finally {
            sampling = false;
          }
        }

        final memoryTimer = Timer.periodic(
          const Duration(milliseconds: 250),
          (_) => unawaited(sample()),
        );
        try {
          final status = await client.status();
          expect(status.jniLoaded, isTrue);
          expect(status.abi, 'x86_64');
          await expectLater(
            client.initializeLlm('/data/local/tmp/arbitrary-model'),
            throwsA(isA<AiRuntimeFailure>()),
          );
          var watch = Stopwatch()..start();
          await client
              .initializeEmbedding('b08-embedding-staging-v1')
              .timeout(const Duration(minutes: 4));
          metrics['embeddingInitializeMs'] = watch.elapsedMilliseconds;
          final embeddingResults = <Map<String, Object?>>[];
          for (final query in [
            'اختبار البحث المحلي',
            'ما وظيفة الخلية؟',
            'Local embedding engineering test',
          ]) {
            final result = await client
                .embed(query)
                .timeout(const Duration(minutes: 2));
            expect(result.values.length, 768);
            expect(result.values.every((v) => v.isFinite), isTrue);
            final norm = math.sqrt(
              result.values.fold<double>(0, (a, v) => a + v * v),
            );
            expect(norm, greaterThan(0));
            embeddingResults.add({
              'dimensions': result.values.length,
              'l2Norm': norm,
              'elapsedMs': result.elapsedMs,
              'finite': true,
              'zero': false,
            });
          }
          metrics['embeddingQueries'] = embeddingResults;
          metrics['embeddingOptions'] =
              'nullable SDK defaults; no adopted Dataset parity policy';
          await client.closeEmbedding();
          expect((await client.status()).embeddingLoaded, isFalse);
          await sample();
          watch = Stopwatch()..start();
          await client
              .initializeLlm('b08-qwen3-staging-v1')
              .timeout(const Duration(minutes: 5));
          metrics['llmInitializeMs'] = watch.elapsedMilliseconds;
          final generations = <Map<String, Object?>>[];
          for (final input in [
            'Reply with just the word HELLO. /no_think',
            'أجب بكلمة مرحبًا فقط. /no_think',
            'Reply with just the word SIRAJ. /no_think',
          ]) {
            final elapsed = Stopwatch()..start();
            int? firstChunk;
            int chunks = 0, characters = 0, terminals = 0;
            AiGenerationEventType? terminal;
            final run = await client.generate(
              systemInstruction:
                  'This is an isolated runtime engineering test. Give a short answer only.',
              input: input,
            );
            await for (final event in run.events.timeout(
              const Duration(minutes: 3),
            )) {
              if (event.type == AiGenerationEventType.chunk) {
                firstChunk ??= elapsed.elapsedMilliseconds;
                chunks++;
                characters += event.text!.length;
              }
              if ([
                AiGenerationEventType.completed,
                AiGenerationEventType.failed,
                AiGenerationEventType.cancelled,
              ].contains(event.type)) {
                terminal = event.type;
                terminals++;
              }
            }
            expect(terminal, AiGenerationEventType.completed);
            expect(terminals, 1);
            expect(characters, greaterThan(0));
            generations.add({
              'firstTextChunkMs': firstChunk,
              'totalMs': elapsed.elapsedMilliseconds,
              'chunks': chunks,
              'characters': characters,
              'terminalCount': terminals,
            });
          }
          metrics['llmGenerations'] = generations;
          watch = Stopwatch()..start();
          String? cancellationTerminal;
          var cancellationAttempts = 0;
          for (; cancellationAttempts < 3; cancellationAttempts++) {
            final expectedId = 'b08-model-request-$requestSerial';
            final nativeTerminal = observeNativeTerminal(bus, expectedId);
            final cancelling = await client.generate(
              systemInstruction:
                  'Runtime cancellation test. Output a long list.',
              input:
                  'List every integer from 1 to 100, one per line. /no_think',
            );
            expect(cancelling.requestId, expectedId);
            bool requested = false;
            Stopwatch? cancelLatency;
            await for (final event in cancelling.events.timeout(
              const Duration(minutes: 3),
            )) {
              if (event.type == AiGenerationEventType.chunk && !requested) {
                requested = true;
                cancelLatency = Stopwatch()..start();
                await cancelling.cancel();
              }
            }
            final actualTerminal = await nativeTerminal.timeout(
              const Duration(minutes: 1),
            );
            cancellationTerminal = actualTerminal['type'] as String;
            if (requested && cancellationTerminal == 'generationCancelled') {
              metrics['nativeCancellationDrainMs'] =
                  cancelLatency!.elapsedMilliseconds;
              break;
            }
            if (cancellationTerminal == 'generationFailed') {
              throw const AiRuntimeFailure(AiRuntimeErrorCode.generationFailed);
            }
            // A correctly completed request cannot be cancelled retroactively.
            // Retry a bounded probe; never count a completion as cancellation.
          }
          if (cancellationTerminal != 'generationCancelled') {
            debugPrint('SIRAJ_B08_MODEL_FAILURE cancellationNotDemonstrated');
            throw const AiRuntimeFailure(AiRuntimeErrorCode.generationFailed);
          }
          await client.closeLlm().timeout(const Duration(minutes: 1));
          metrics['cancellationProbeAndCloseTotalMs'] =
              watch.elapsedMilliseconds;
          metrics['nativeCancellationTerminal'] = cancellationTerminal;
          metrics['cancellationAttempts'] = cancellationAttempts + 1;
          expect((await client.status()).llmLoaded, isFalse);
          watch = Stopwatch()..start();
          await client
              .initializeLlm('b08-qwen3-staging-v1')
              .timeout(const Duration(minutes: 5));
          metrics['llmReloadMs'] = watch.elapsedMilliseconds;
          final reloaded = await client.generate(
            systemInstruction: 'Answer briefly.',
            input: 'Say hello. /no_think',
          );
          final reloadedEvents = await reloaded.events
              .timeout(const Duration(minutes: 3))
              .toList();
          expect(reloadedEvents.last.type, AiGenerationEventType.completed);
          expect(
            reloadedEvents.any(
              (e) =>
                  e.type == AiGenerationEventType.chunk && e.text!.isNotEmpty,
            ),
            isTrue,
          );
          await client.closeLlm();
          await sample();
          metrics.addAll({
            'status': 'PASS',
            'modelInferenceExecuted': true,
            'failureCount': 0,
            'assertedNonemptyCompletionCount': 4,
            'generationAttemptCount': 4 + cancellationAttempts + 1,
            'cancelProbeNormalCompletions': cancellationAttempts,
            'embeddingQueryCount': 3,
            'memorySamples': samples,
            'sampledPeakPssKb': sampledPeakPssKb,
            'sampledPeakNativeHeapBytes': maxNativeHeapBytes,
            'memorySamplePeriodMs': 250,
            'memoryCaveat':
                'sampled app process peaks, not guaranteed absolute peaks or co-residency approval',
          });
          debugPrint('SIRAJ_B08_MODEL_METRICS ${jsonEncode(metrics)}');
          return true;
        } on AiRuntimeFailure catch (error) {
          debugPrint('SIRAJ_B08_MODEL_FAILURE ${error.code.name}');
          rethrow;
        } finally {
          memoryTimer.cancel();
          await client.dispose();
        }
      });
      expect(passed, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}
