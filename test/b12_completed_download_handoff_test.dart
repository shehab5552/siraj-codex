import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_service.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';
import 'support/download_server.dart';
import 'support/b12_dataset_fixture.dart';

void main() {
  late Directory root;
  late DownloadTestServer server;
  late DownloadService<ResourceDownloadEvidence> downloads;
  late DownloadSpec spec;
  final bytes = utf8.encode('SYNTHETIC COMPLETED DATA');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('siraj-handoff-test-');
    server = await DownloadTestServer.start();
    server.respond = (r, _) => DownloadTestServer.full(r, bytes);
    final hash = await Sha256().hash(bytes);
    spec = DownloadSpec(
      resourceId: 'test',
      artifactRevision: 'test-r1',
      kind: ResourceContractKind.ragPack,
      url: server.url,
      destinationKey: 'test',
      maxBytes: bytes.length,
      expectedSize: bytes.length,
      expectedSha256: hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
    downloads = DownloadService(
      appSupportDirectory: root,
      spaceProbe: TestDatasetSpace(),
      validator: const ResourceDownloadValidator(),
      clientFactory: server.client,
    );
  });
  tearDown(() async {
    await server.close();
    await root.delete(recursive: true);
  });
  test(
    'completed provenance is reopened under an exclusive lease without another HTTP transfer',
    () async {
      expect(
        (await downloads.start(spec).result).state,
        DownloadState.downloaded,
      );
      final data = await downloads.withCompletedArtifact(
        spec,
        (file) => file.readAsBytes(),
      );
      expect(data, bytes);
      expect(server.requests.length, 1);
    },
  );
  test(
    'handoff retains writer exclusion until its asynchronous consumer drains',
    () async {
      expect(
        (await downloads.start(spec).result).state,
        DownloadState.downloaded,
      );
      final entered = Completer<void>();
      final finish = Completer<void>();
      final reading = downloads.withCompletedArtifact(spec, (file) async {
        entered.complete();
        await finish.future;
        return file.readAsBytes();
      });
      await entered.future;
      expect(
        (await downloads.start(spec).result).failure?.code,
        DownloadFailureCode.busy,
      );
      await expectLater(
        downloads.discardCorruptCompletedArtifact(spec),
        throwsA(
          isA<DownloadFailure>().having(
            (e) => e.code,
            'code',
            DownloadFailureCode.busy,
          ),
        ),
      );
      finish.complete();
      expect(await reading, bytes);
    },
  );
  test('tampered completed bytes never reach the assembler', () async {
    final result = await downloads.start(spec).result;
    await result.stagedFile!.writeAsString('corrupt');
    var reached = false;
    await expectLater(
      downloads.withCompletedArtifact(spec, (file) async {
        reached = true;
      }),
      throwsA(isA<DownloadFailure>()),
    );
    expect(reached, false);
  });
  test(
    'foreign completed identity is rejected without deleting the candidate',
    () async {
      await downloads.start(spec).result;
      final foreign = DownloadSpec(
        resourceId: 'different',
        artifactRevision: spec.artifactRevision,
        kind: spec.kind,
        url: spec.url,
        destinationKey: spec.destinationKey,
        maxBytes: spec.maxBytes,
        expectedSize: spec.expectedSize,
        expectedSha256: spec.expectedSha256,
      );
      await expectLater(
        downloads.withCompletedArtifact(foreign, (file) => file.readAsBytes()),
        throwsA(isA<DownloadFailure>()),
      );
      expect(await downloads.discardCorruptCompletedArtifact(foreign), isFalse);
      expect(
        await downloads.withCompletedArtifact(
          spec,
          (file) => file.readAsBytes(),
        ),
        bytes,
      );
      expect(server.requests.length, 1);
    },
  );
  for (final corrupt in ['utf8', 'oversized']) {
    test('completed $corrupt provenance never reaches the assembler', () async {
      await downloads.start(spec).result;
      final metadata = File(
        '${root.path}/downloads-staging-v1/test/provenance.json',
      );
      await metadata.writeAsBytes(
        corrupt == 'utf8' ? [0xff, 0xfe] : List.filled(20000, 0x20),
      );
      var reached = false;
      await expectLater(
        downloads.withCompletedArtifact(spec, (file) async {
          reached = true;
        }),
        throwsA(isA<DownloadFailure>()),
      );
      expect(reached, false);
      expect(await downloads.discardCorruptCompletedArtifact(spec), isFalse);
      expect(await metadata.exists(), isTrue);
      expect(server.requests.length, 1);
    });
  }
  test(
    'consumer failure releases writer exclusion without discarding trusted bytes',
    () async {
      await downloads.start(spec).result;
      await expectLater(
        downloads.withCompletedArtifact(spec, (file) async {
          throw StateError('isolated consumer failure');
        }),
        throwsStateError,
      );
      expect(
        await downloads.withCompletedArtifact(
          spec,
          (file) => file.readAsBytes(),
        ),
        bytes,
      );
    },
  );
  test('explicit recovery preserves a valid completed artifact', () async {
    await downloads.start(spec).result;
    expect(await downloads.discardCorruptCompletedArtifact(spec), isFalse);
    expect(
      await downloads.withCompletedArtifact(spec, (f) => f.readAsBytes()),
      bytes,
    );
    expect(server.requests, hasLength(1));
  });
  test(
    'explicit recovery refuses completed metadata with a forged identity',
    () async {
      final result = await downloads.start(spec).result;
      final metadata = File(
        '${root.path}/downloads-staging-v1/test/provenance.json',
      );
      final data =
          jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      data['identity'] = '0' * 64;
      await metadata.writeAsString(jsonEncode(data));
      await result.stagedFile!.writeAsString('damaged');
      expect(await downloads.discardCorruptCompletedArtifact(spec), isFalse);
      expect(await result.stagedFile!.readAsString(), 'damaged');
      expect(
        (await downloads.start(spec).result).failure?.code,
        DownloadFailureCode.candidateExists,
      );
    },
  );
}
