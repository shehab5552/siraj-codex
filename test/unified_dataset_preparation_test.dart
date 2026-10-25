import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/dataset_preparation.dart';
import 'package:siraj/features/resources/dataset_release_contracts.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/download_service.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'support/b12_dataset_fixture.dart';
import 'support/download_server.dart';

class _Downloads implements ApprovedDatasetDownloads {
  _Downloads(this.server, {this.artifactRevision});
  final String? artifactRevision;
  final DownloadTestServer server;
  @override
  Future<List<DatasetDownloadPart>?> resolve(DatasetReleasePlan plan) async => [
    for (final c in plan.components)
      DatasetDownloadPart(
        componentId: c.id,
        spec: DownloadSpec(
          resourceId: c.id,
          artifactRevision: artifactRevision ?? plan.revision,
          kind: c.kind,
          url: server.url.replace(path: '/${plan.revision}/${c.id}'),
          destinationKey: '${plan.revision}-${c.id}',
          maxBytes: c.files.single.sizeBytes,
          expectedSize: c.files.single.sizeBytes,
          expectedSha256: c.files.single.sha256,
        ),
        assembler: const DirectDatasetFileAssembler(),
      ),
  ];
}

void main() {
  late DatasetFixture f;
  late DownloadTestServer server;
  late DownloadService<ResourceDownloadEvidence> download;
  setUp(() async {
    f = DatasetFixture();
    await f.initialize();
    server = await DownloadTestServer.start();
    server.respond = (r, _) async {
      final parts = r.uri.pathSegments;
      final component = f.plans.plans[parts[0]]!.components.singleWhere(
        (c) => c.id == parts[1],
      );
      await DownloadTestServer.full(
        r,
        f.plans.contents[parts[0]]![component.files.single.path]!,
      );
    };
    download = DownloadService(
      appSupportDirectory: f.support,
      spaceProbe: f.space,
      validator: const ResourceDownloadValidator(),
      clientFactory: server.client,
    );
  });
  tearDown(() async {
    await server.close();
    await f.close();
  });
  DatasetPreparationCoordinator coordinator() => DatasetPreparationCoordinator(
    downloads: download,
    manager: f.manager,
    catalog: _Downloads(server),
  );
  test(
    'single consent downloads five packs plus shared embedding and commits verified pointer',
    () async {
      final c = coordinator();
      expect(
        await c.prepareAndActivate(
          revision: 'r1',
          candidateId: 'prepare-r1',
          consented: true,
        ),
        'r1',
      );
      expect(server.requests.length, 6);
      expect(c.phase, DatasetPreparationPhase.active);
      expect((await f.manager.recover()).activeRevision, 'r1');
      c.dispose();
    },
  );
  test('failed upgrade preserves prior revision and pinned readers', () async {
    await f.activate('r1');
    final pin = await f.pin();
    final previous = await f.releasedFile('r1').readAsBytes();
    server.respond = (r, _) => DownloadTestServer.full(r, List.filled(3, 0));
    final c = coordinator();
    await expectLater(
      c.prepareAndActivate(
        revision: 'r2',
        candidateId: 'prepare-r2',
        consented: true,
      ),
      throwsA(anything),
    );
    expect(c.phase, DatasetPreparationPhase.failed);
    expect((await f.manager.recover()).activeRevision, 'r1');
    expect(pin.revision, 'r1');
    expect(await f.releasedFile('r1').readAsBytes(), previous);
    c.dispose();
  });
  test(
    'runtime validator unavailable never yields ACTIVE after valid transfers',
    () async {
      await f.manager.close();
      await f.reopen(
        selectedValidator: const UnavailableDatasetRuntimeValidator(),
      );
      final c = coordinator();
      await expectLater(
        c.prepareAndActivate(
          revision: 'r1',
          candidateId: 'not-validated',
          consented: true,
        ),
        throwsA(isA<DatasetFailure>()),
      );
      expect(c.phase, DatasetPreparationPhase.failed);
      expect((await f.manager.recover()).activeRevision, isNull);
      c.dispose();
    },
  );
  test('no consent never contacts network or prepares candidate', () async {
    final c = coordinator();
    await expectLater(
      c.prepareAndActivate(
        revision: 'r1',
        candidateId: 'no-consent',
        consented: false,
      ),
      throwsA(anything),
    );
    expect(server.requests, isEmpty);
    expect(
      (await Directory('${f.support.path}/rag/staging').list().toList()),
      isEmpty,
    );
    c.dispose();
  });
  test(
    'retry reuses completed provenance after runtime validation failure',
    () async {
      f.validator.failure = const DatasetFailure(
        DatasetFailureCode.validationFailed,
      );
      final c = coordinator();
      await expectLater(
        c.prepareAndActivate(
          revision: 'r1',
          candidateId: 'first',
          consented: true,
        ),
        throwsA(isA<DatasetFailure>()),
      );
      expect(server.requests.length, 6);
      f.validator.failure = null;
      expect(
        await c.prepareAndActivate(
          revision: 'r1',
          candidateId: 'retry',
          consented: true,
        ),
        'r1',
      );
      expect(server.requests.length, 6);
      c.dispose();
    },
  );
  test(
    'cancel drains an active TLS transfer and permits a safe restart',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final original = server.respond;
      server.respond = (request, index) async {
        entered.complete();
        await release.future;
        await original(request, index);
      };
      final c = coordinator();
      final pending = c.prepareAndActivate(
        revision: 'r1',
        candidateId: 'cancelled',
        consented: true,
      );
      final settled = expectLater(
        pending,
        throwsA(
          isA<DatasetFailure>().having(
            (e) => e.code,
            'code',
            DatasetFailureCode.cancelled,
          ),
        ),
      );
      await entered.future;
      await c.cancel();
      await settled;
      expect(c.phase, DatasetPreparationPhase.cancelled);
      expect((await f.manager.recover()).activeRevision, isNull);
      release.complete();
      server.respond = original;
      expect(
        await c.prepareAndActivate(
          revision: 'r1',
          candidateId: 'restart',
          consented: true,
        ),
        'r1',
      );
      c.dispose();
    },
  );
  for (final damage in ['size', 'hash', 'missing']) {
    test(
      'retry replaces only damaged completed staging payload ($damage) and preserves active release',
      () async {
        await f.activate('r1');
        final active = await f.releasedFile('r1').readAsBytes();
        f.validator.failure = const DatasetFailure(
          DatasetFailureCode.validationFailed,
        );
        final c = coordinator();
        addTearDown(c.dispose);
        await expectLater(
          c.prepareAndActivate(
            revision: 'r2',
            candidateId: 'damaged-first',
            consented: true,
          ),
          throwsA(isA<DatasetFailure>()),
        );
        expect(server.requests, hasLength(6));
        final plan = f.plans.plans['r2']!;
        final part = (await _Downloads(server).resolve(plan))!.first;
        final payload = File(
          '${f.support.path}/downloads-staging-v1/${part.spec.destinationKey}/payload.part',
        );
        if (damage == 'missing') {
          await payload.delete();
        } else if (damage == 'hash') {
          final bytes = await payload.readAsBytes();
          bytes[0] ^= 0xff;
          await payload.writeAsBytes(bytes);
        } else {
          await payload.writeAsBytes([1]);
        }
        f.validator.failure = null;
        expect(
          await c.prepareAndActivate(
            revision: 'r2',
            candidateId: 'damaged-retry',
            consented: true,
          ),
          'r2',
        );
        expect(server.requests, hasLength(7));
        expect(await f.releasedFile('r1').readAsBytes(), active);
        expect((await f.manager.recover()).activeRevision, 'r2');
      },
    );
  }
  test(
    'approved artifact version can differ from the dataset revision',
    () async {
      final c = DatasetPreparationCoordinator(
        downloads: download,
        manager: f.manager,
        catalog: _Downloads(server, artifactRevision: 'artifact-build-7'),
      );
      expect(
        await c.prepareAndActivate(
          revision: 'r1',
          candidateId: 'independent-artifact',
          consented: true,
        ),
        'r1',
      );
      expect(server.requests.length, 6);
      c.dispose();
    },
  );
}
