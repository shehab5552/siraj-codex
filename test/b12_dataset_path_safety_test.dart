import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/dataset_release_contracts.dart';
import 'support/b12_dataset_fixture.dart';

Matcher fails(DatasetFailureCode code) =>
    throwsA(isA<DatasetFailure>().having((e) => e.code, 'code', code));
void main() {
  late DatasetFixture f;
  setUp(() async {
    f = DatasetFixture();
    await f.initialize();
  });
  tearDown(() async {
    await f.close();
  });
  for (final id in [
    '../outside',
    '/absolute',
    'a/b',
    'a\\b',
    '..',
    'a:b',
    'a\u0000b',
  ]) {
    test(
      'unsafe candidate ID rejected: ${id.replaceAll('\u0000', 'NUL')}',
      () async {
        await expectLater(
          f.manager.prepareCandidate(candidateId: id, revision: 'r1'),
          fails(DatasetFailureCode.unsafePath),
        );
        expect(await f.store.read(), null);
      },
    );
  }
  test(
    'unknown approved revision fails closed without inventing a manifest',
    () async {
      await expectLater(
        f.manager.prepareCandidate(
          candidateId: 'unknown',
          revision: 'unapproved',
        ),
        fails(DatasetFailureCode.validatorUnavailable),
      );
      expect(await f.store.read(), null);
    },
  );
  test('catalog artifact traversal cannot become a write path', () async {
    final p = f.plans.plans['r1']!;
    final first = p.components.first;
    f.plans.plans['r1'] = DatasetReleasePlan(
      declaration: p.declaration,
      components: [
        DatasetComponent(
          id: first.id,
          kind: first.kind,
          files: [
            DatasetArtifact(
              path: '../outside',
              sizeBytes: first.files.first.sizeBytes,
              sha256: first.files.first.sha256,
            ),
          ],
        ),
        ...p.components.skip(1),
      ],
    );
    await expectLater(
      f.manager.prepareCandidate(candidateId: 'unsafe', revision: 'r1'),
      fails(DatasetFailureCode.invalidPlan),
    );
    expect(await File('${f.support.path}/outside').exists(), false);
  });
  test(
    'unexpected files and directories are rejected rather than silently promoted',
    () async {
      final c = await f.candidate('r1');
      await File(
        '${f.support.path}/rag/staging/${c.id}/extra',
      ).writeAsString('unexpected');
      await expectLater(
        f.manager.verifyCandidate(c),
        fails(DatasetFailureCode.unsafePath),
      );
      expect(await f.store.read(), null);
    },
  );
  test(
    'symlink in candidate cannot read outside staging or be recursively removed',
    () async {
      final c = await f.candidate('r1');
      final outside = File('${f.support.path}/outside');
      await outside.writeAsString('KEEP');
      await f.stagedFile(c).delete();
      await Link(f.stagedFile(c).path).create(outside.path);
      await expectLater(
        f.manager.verifyCandidate(c),
        fails(DatasetFailureCode.unsafePath),
      );
      await expectLater(
        f.manager.discardCandidate(c),
        fails(DatasetFailureCode.unsafePath),
      );
      expect(await outside.readAsString(), 'KEEP');
    },
  );
  test(
    'symlinked writer parent is rejected before opening a payload',
    () async {
      final c = await f.manager.prepareCandidate(
        candidateId: 'links',
        revision: 'r1',
      );
      final outside = await Directory('${f.support.path}/outside-dir').create();
      await Link(
        '${f.support.path}/rag/staging/${c.id}/packs',
      ).create(outside.path);
      await expectLater(
        f.manager.writeArtifact(c, 'packs/test-0/index.bin', Stream.value([1])),
        fails(DatasetFailureCode.unsafePath),
      );
      expect(await outside.list().toList(), isEmpty);
    },
  );
  test(
    'release cleanup rejects symlink and leaves its destination intact',
    () async {
      await f.activate('r1');
      await f.activate('r2');
      final file = f.releasedFile('r1');
      await file.delete();
      await Link(file.path).create(f.releasedFile('r2').path);
      await expectLater(
        f.manager.removeUnreferenced('r1'),
        fails(DatasetFailureCode.unsafePath),
      );
      expect(await f.releasedFile('r2').exists(), true);
      expect((await f.store.read())?.revision, 'r2');
    },
  );
  test(
    'pointer path cannot select another directory even when revision is approved',
    () async {
      await f.activate('r1');
      await f.db.customStatement(
        "UPDATE installed_resource SET local_path='/outside' WHERE resource_id='__ACTIVE_DATASET__'",
      );
      await expectLater(
        f.manager.openHandle(),
        fails(DatasetFailureCode.sourceUnavailable),
      );
      expect((await f.manager.recover()).activeRevision, null);
    },
  );
  test(
    'approved plan identity change invalidates an outstanding receipt',
    () async {
      final c = await f.candidate('r1');
      final v = await f.manager.verifyCandidate(c);
      final p = f.plans.plans['r1']!;
      final first = p.components.first;
      final file = first.files.first;
      f.plans.plans['r1'] = DatasetReleasePlan(
        declaration: p.declaration,
        components: [
          DatasetComponent(
            id: first.id,
            kind: first.kind,
            files: [
              DatasetArtifact(
                path: file.path,
                sizeBytes: file.sizeBytes,
                sha256: '0' * 64,
              ),
            ],
          ),
          ...p.components.skip(1),
        ],
      );
      await expectLater(
        f.manager.commitActiveRevision(v),
        fails(DatasetFailureCode.candidateChanged),
      );
      expect(await f.store.read(), null);
    },
  );
  test(
    'cancelled assembly removes partial file, never a prior active resource',
    () async {
      await f.activate('r1');
      final c = await f.manager.prepareCandidate(
        candidateId: 'cancel',
        revision: 'r2',
      );
      final cancellation = DatasetCancellation();
      Stream<List<int>> interrupted() async* {
        yield [1];
        cancellation.cancel();
        yield [2];
      }

      await expectLater(
        f.manager.writeArtifact(
          c,
          'packs/test-0/index.bin',
          interrupted(),
          cancellation: cancellation,
        ),
        fails(DatasetFailureCode.cancelled),
      );
      expect(await f.stagedFile(c).exists(), false);
      expect((await f.store.read())?.revision, 'r1');
    },
  );
  test(
    'incomplete and oversized assembly cannot become a candidate artifact',
    () async {
      final c = await f.manager.prepareCandidate(
        candidateId: 'sizes',
        revision: 'r1',
      );
      await expectLater(
        f.manager.writeArtifact(c, 'packs/test-0/index.bin', Stream.value([1])),
        fails(DatasetFailureCode.incomplete),
      );
      await expectLater(
        f.manager.writeArtifact(
          c,
          'packs/test-0/index.bin',
          Stream.value(List.filled(4096, 0)),
        ),
        fails(DatasetFailureCode.integrityFailed),
      );
      expect(await f.stagedFile(c).exists(), false);
    },
  );
  test(
    'live candidate cannot be removed through abandoned-candidate API',
    () async {
      final c = await f.candidate('r1');
      await expectLater(
        f.manager.discardAbandonedCandidate(c.id),
        fails(DatasetFailureCode.busy),
      );
      await f.manager.discardCandidate(c);
      expect(await f.stagedFile(c).exists(), false);
    },
  );
}
