import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:siraj/features/auth/kdf_worker.dart';
import 'package:siraj/features/auth/password_hasher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android candidate 600k metrics and cancellation, not production approval',
    (tester) async {
      expect(
        Platform.isAndroid,
        isTrue,
        reason: 'Run this target on Android only',
      );
      await tester.pumpWidget(
        const MaterialApp(home: CircularProgressIndicator()),
      );
      final metrics = await tester.runAsync(() async {
        final hasher = PasswordHasher(
          iterations: PasswordHasher.candidateIterations,
        );
        final samples = <Map<String, Object>>[];
        for (var i = 0; i < 3; i++) {
          var ticks = 0;
          var previous = 0;
          var gap = 0;
          final watch = Stopwatch()..start();
          final before = ProcessInfo.currentRss;
          final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
            final now = watch.elapsedMicroseconds;
            if (now - previous > gap) gap = now - previous;
            previous = now;
            ticks++;
          });
          try {
            final credential = await hasher.hashPassword(
              'synthetic-android-candidate-only',
            );
            credential.hash.fillRange(0, credential.hash.length, 0);
            expect(
              ticks,
              greaterThan(0),
              reason: 'Parent event loop must progress',
            );
            samples.add({
              'sample': i + 1,
              'iterations': 600000,
              'elapsed_ms': watch.elapsedMilliseconds,
              'heartbeat_ticks': ticks,
              'max_heartbeat_gap_ms': gap / 1000,
              'process_rss_before_bytes': before,
              'process_rss_after_bytes': ProcessInfo.currentRss,
            });
          } finally {
            timer.cancel();
          }
        }
        final cancellation = KdfCancellation();
        final worker = IsolatePbkdf2();
        final task = worker.derive(
          password: 'synthetic-cancel-only',
          salt: Uint8List(16),
          iterations: 5000000,
          cancellation: cancellation,
        );
        final settled = task.then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final cancelWatch = Stopwatch()..start();
        cancellation.cancel();
        final result = await settled;
        expect(
          result,
          isA<KdfFailure>().having(
            (e) => e.code,
            'code',
            KdfFailureCode.cancelled,
          ),
        );
        return {
          'platform': 'android',
          'samples': samples,
          'cancel_settlement_ms': cancelWatch.elapsedMicroseconds / 1000,
          'production_approved': false,
          'note':
              'Process RSS and event-loop heartbeat only; not frame/ANR/leak-free proof',
        };
      });
      debugPrint('SIRAJ_B04_METRICS ${jsonEncode(metrics)}');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
