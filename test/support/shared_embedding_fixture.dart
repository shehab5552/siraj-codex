import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:siraj/integrations/ai/shared_embedding_runtime_contract.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'b09_ai_fixture.dart' as rag;

/// Native-boundary double only; no real vector/Android/scientific claim.
class TestEmbeddingBackend implements EmbeddingBackend {
  final requests = <EmbeddingRequest>[];
  final events = <String>[];
  EmbeddingCapabilities? capabilities;
  Object? loadError, embedError;
  bool failUnload = false;
  Completer<List<double>>? pending;
  Completer<EmbeddingCapabilities>? pendingLoad;
  Completer<void>? cancelDrain;
  List<double> vector = [1, 0];
  @override
  Future<EmbeddingCapabilities> load(
    SharedEmbeddingConfig config,
    TutorCancellation cancellation,
  ) async {
    events.add('load');
    if (loadError != null) throw loadError!;
    if (pendingLoad != null) return pendingLoad!.future;
    return capabilities ??
        EmbeddingCapabilities(
          runtimeId: config.runtimeId,
          binding: config.binding,
          supportsCancellation: true,
        );
  }

  @override
  Future<List<double>> embed(
    EmbeddingRequest request,
    TutorCancellation cancellation,
  ) async {
    events.add('embed');
    requests.add(request);
    if (embedError != null) throw embedError!;
    return pending?.future ?? vector;
  }

  @override
  Future<void> cancel(String requestId) async {
    events.add('cancel');
    if (cancelDrain != null) await cancelDrain!.future;
  }

  @override
  Future<void> unload() async {
    events.add('unload');
    if (failUnload) throw StateError('test-only unload error');
  }
}

class EmbeddingFixture {
  late Directory directory;
  late SharedEmbeddingConfig config;
  final backend = TestEmbeddingBackend();
  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp('siraj-embedding-test-');
    await Directory('${directory.path}/shared').create();
    final files = <EmbeddingArtifact>[];
    for (final entry in {
      'shared/test.bin': 'SYNTHETIC EMBEDDING',
      'shared/tokenizer.cfg': 'SYNTHETIC TOKENIZER',
    }.entries) {
      final bytes = utf8.encode(entry.value);
      await File(
        '${directory.path}/${entry.key}',
      ).writeAsBytes(bytes, flush: true);
      final digest = await Sha256().hash(bytes);
      files.add(
        EmbeddingArtifact(
          relativePath: entry.key,
          sizeBytes: bytes.length,
          sha256: digest.bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
        ),
      );
    }
    config = SharedEmbeddingConfig(
      binding: rag.binding,
      artifactRoot: directory,
      runtimeId: 'TEST_RUNTIME',
      artifacts: files,
    );
  }

  Future<void> close() => directory.delete(recursive: true);
}
