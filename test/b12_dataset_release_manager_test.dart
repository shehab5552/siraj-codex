import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/dataset_release_contracts.dart';
import 'package:siraj/features/resources/dataset_release_manager.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';
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
  test(
    'complete six-component release promotes then commits exactly one pointer',
    () async {
      await f.activate('r1');
      final row = await f.store.read();
      expect(row?.revision, 'r1');
      expect(row?.state, 'READY');
      expect(
        await f.releasedFile('r1').readAsBytes(),
        f.plans.contents['r1']!['packs/test-0/index.bin'],
      );
      final h = await f.pin();
      expect(h.revision, 'r1');
      expect(
        h.plan.components
            .where((c) => c.kind == ResourceContractKind.ragEmbedding)
            .length,
        1,
      );
      expect(
        (await f.db.customSelect('SELECT * FROM installed_resource').get())
            .length,
        1,
      );
      expect(
        (await f.db.customSelect('SELECT * FROM conversation').get()),
        isEmpty,
      );
    },
  );
  test('old reader remains pinned while new revision becomes active', () async {
    await f.activate('r1');
    final h = await f.pin();
    final before = await f.releasedFile('r1').readAsBytes();
    await f.activate('r2');
    expect((await f.store.read())?.revision, 'r2');
    expect(h.revision, 'r1');
    expect(
      await File('${h.directory.path}/packs/test-0/index.bin').readAsBytes(),
      before,
    );
    await expectLater(
      f.manager.removeUnreferenced('r1'),
      fails(DatasetFailureCode.pinned),
    );
    await expectLater(
      f.manager.removeUnreferenced('r2'),
      fails(DatasetFailureCode.pinned),
    );
    h.release();
    h.release();
    await f.manager.removeUnreferenced('r1');
    expect(await f.releasedFile('r1').exists(), false);
    expect(await f.releasedFile('r2').exists(), true);
  });
  test(
    'single-instance embedder validation waits for old readers to drain',
    () async {
      await f.activate('r1');
      final h = await f.pin();
      final c = await f.candidate('r2');
      f.validator.supportsPinnedValidation = false;
      await expectLater(
        f.manager.verifyCandidate(c),
        fails(DatasetFailureCode.pinned),
      );
      expect((await f.store.read())?.revision, 'r1');
      h.release();
      await f.manager.commitActiveRevision(await f.manager.verifyCandidate(c));
      expect((await f.store.read())?.revision, 'r2');
    },
  );
  test(
    'readers of the same validated revision do not reload a single-instance embedder',
    () async {
      f.validator.supportsPinnedValidation = false;
      await f.activate('r1');
      final first = await f.pin();
      final second = await f.pin();
      expect(first.revision, second.revision);
      expect(f.validator.calls, ['r1']);
    },
  );
  test(
    'missing file prevents verification and preserves previous active bytes',
    () async {
      await f.activate('r1');
      final before = await f.releasedFile('r1').readAsBytes();
      final c = await f.candidate('r2');
      await f.stagedFile(c).delete();
      await expectLater(
        f.manager.verifyCandidate(c),
        fails(DatasetFailureCode.incomplete),
      );
      expect((await f.store.read())?.revision, 'r1');
      expect(await f.releasedFile('r1').readAsBytes(), before);
    },
  );
  test('same-size corruption fails real SHA256 verification', () async {
    final c = await f.candidate('r1');
    final file = f.stagedFile(c);
    final bytes = await file.readAsBytes();
    bytes[0] ^= 1;
    await file.writeAsBytes(bytes);
    await expectLater(
      f.manager.verifyCandidate(c),
      fails(DatasetFailureCode.integrityFailed),
    );
    expect(await f.store.read(), null);
  });
  test('changed bytes after receipt are rechecked before promotion', () async {
    await f.activate('r1');
    final c = await f.candidate('r2');
    final v = await f.manager.verifyCandidate(c);
    await f.stagedFile(c).writeAsString('corrupt');
    await expectLater(
      f.manager.commitActiveRevision(v),
      fails(DatasetFailureCode.integrityFailed),
    );
    expect((await f.store.read())?.revision, 'r1');
    expect(await f.releasedFile('r2').exists(), false);
  });
  test('semantic/runtime failure cannot produce a verified receipt', () async {
    await f.activate('r1');
    final c = await f.candidate('r2');
    f.validator.failure = const DatasetFailure(DatasetFailureCode.incompatible);
    await expectLater(
      f.manager.verifyCandidate(c),
      fails(DatasetFailureCode.incompatible),
    );
    expect((await f.store.read())?.revision, 'r1');
  });
  test(
    'unavailable production validator never publishes byte-valid synthetic files',
    () async {
      await f.manager.close();
      await f.reopen(
        selectedValidator: const UnavailableDatasetRuntimeValidator(),
      );
      await expectLater(
        f.manager.verifyCandidate(await f.candidate('r1')),
        fails(DatasetFailureCode.validatorUnavailable),
      );
      expect(await f.store.read(), null);
    },
  );
  test(
    'one-pack fixture cannot enter the production activation path',
    () async {
      final p = f.plans.plans['r1']!;
      f.plans.plans['r1'] = DatasetReleasePlan(
        declaration: p.declaration,
        components: [p.components.first, p.components.last],
      );
      await expectLater(
        f.manager.prepareCandidate(candidateId: 'fixture', revision: 'r1'),
        fails(DatasetFailureCode.invalidPlan),
      );
      expect(await f.store.read(), null);
    },
  );
  test(
    'foreign LLM or PDF artifacts cannot enter the dataset release',
    () async {
      final p = f.plans.plans['r1']!;
      f.plans.plans['r1'] = DatasetReleasePlan(
        declaration: p.declaration,
        components: [
          ...p.components,
          DatasetComponent(
            id: 'pdf',
            kind: ResourceContractKind.pdf,
            files: p.components.first.files,
          ),
        ],
      );
      await expectLater(
        f.manager.prepareCandidate(candidateId: 'bad', revision: 'r1'),
        fails(DatasetFailureCode.invalidPlan),
      );
    },
  );
  test('revision directory cannot be overwritten even when empty', () async {
    final v = await f.manager.verifyCandidate(await f.candidate('r1'));
    await Directory('${f.support.path}/rag/releases/r1').create();
    await expectLater(
      f.manager.commitActiveRevision(v),
      fails(DatasetFailureCode.releaseExists),
    );
    expect(await f.store.read(), null);
  });
  test(
    'SQLite abort after promotion rolls back pointer and leaves an unreferenced release',
    () async {
      await f.activate('r1');
      final before = await f.store.read();
      final v = await f.manager.verifyCandidate(await f.candidate('r2'));
      await f.db.customStatement(
        "CREATE TRIGGER abort_dataset BEFORE UPDATE ON installed_resource WHEN NEW.resource_id='__ACTIVE_DATASET__' BEGIN SELECT RAISE(ABORT,'test injected'); END",
      );
      await expectLater(
        f.manager.commitActiveRevision(v),
        fails(DatasetFailureCode.databaseFailure),
      );
      expect(await f.store.read(), before);
      expect(await f.releasedFile('r2').exists(), true);
      final recovery = await f.manager.recover();
      expect(recovery.activeRevision, 'r1');
      expect(recovery.unreferencedRevisions, ['r2']);
    },
  );
  test(
    'external pointer change causes compare-and-swap conflict rather than overwrite',
    () async {
      await f.activate('r1');
      final v = await f.manager.verifyCandidate(await f.candidate('r2'));
      await f.db.customStatement(
        "UPDATE installed_resource SET revision='external' WHERE resource_id='__ACTIVE_DATASET__'",
      );
      await expectLater(
        f.manager.commitActiveRevision(v),
        fails(DatasetFailureCode.pointerConflict),
      );
      expect((await f.store.read())?.revision, 'external');
    },
  );
  test(
    'startup revalidates active files and never activates a promoted orphan',
    () async {
      await f.activate('r1');
      final v = await f.manager.verifyCandidate(await f.candidate('r2'));
      await f.db.customStatement(
        "CREATE TRIGGER abort_dataset BEFORE UPDATE ON installed_resource BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        f.manager.commitActiveRevision(v),
        fails(DatasetFailureCode.databaseFailure),
      );
      await f.manager.close();
      await f.reopen();
      var recovery = await f.manager.recover();
      expect(recovery.activeRevision, 'r1');
      expect(recovery.unreferencedRevisions, ['r2']);
      await f.releasedFile('r1').delete();
      recovery = await f.manager.recover();
      expect(recovery.activeRevision, null);
      expect(recovery.failure, DatasetFailureCode.incomplete);
      expect((await f.store.read())?.revision, 'r1');
    },
  );
  test(
    'only one manager may own the root, and close cannot release pinned readers',
    () async {
      await expectLater(
        DatasetReleaseManager.open(appSupport: f.support, store: f.store),
        fails(DatasetFailureCode.busy),
      );
      await f.activate('r1');
      final h = await f.pin();
      await expectLater(f.manager.close(), fails(DatasetFailureCode.pinned));
      h.release();
      await f.manager.close();
      await expectLater(
        f.manager.openHandle(),
        fails(DatasetFailureCode.closed),
      );
      await f.reopen();
      expect((await f.manager.recover()).activeRevision, 'r1');
    },
  );
  test(
    'reverification invalidates previous receipt and sealed candidate rejects writers',
    () async {
      final c = await f.candidate('r1');
      final old = await f.manager.verifyCandidate(c);
      final fresh = await f.manager.verifyCandidate(c);
      await expectLater(
        f.manager.writeArtifact(c, 'packs/test-0/index.bin', Stream.value([1])),
        fails(DatasetFailureCode.unsafePath),
      );
      await expectLater(
        f.manager.commitActiveRevision(old),
        fails(DatasetFailureCode.candidateChanged),
      );
      await f.manager.commitActiveRevision(fresh);
    },
  );
  test(
    'cancel during runtime validation drains it then preserves old active',
    () async {
      await f.activate('r1');
      final c = await f.candidate('r2');
      final cancel = DatasetCancellation();
      f.validator.paused = Completer<void>();
      final pending = f.manager.verifyCandidate(c, cancellation: cancel);
      final result = expectLater(pending, fails(DatasetFailureCode.cancelled));
      while (!f.validator.calls.contains('r2')) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      cancel.cancel();
      await expectLater(f.manager.close(), fails(DatasetFailureCode.busy));
      f.validator.paused!.complete();
      await result;
      expect((await f.store.read())?.revision, 'r1');
    },
  );
  test(
    'concurrent write and verify cannot read a partially written candidate',
    () async {
      final c = await f.manager.prepareCandidate(
        candidateId: 'writing',
        revision: 'r1',
      );
      final stream = StreamController<List<int>>();
      final writing = f.manager.writeArtifact(
        c,
        'packs/test-0/index.bin',
        stream.stream,
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        f.manager.verifyCandidate(c),
        fails(DatasetFailureCode.busy),
      );
      stream.add(f.plans.contents['r1']!['packs/test-0/index.bin']!);
      await stream.close();
      await writing;
    },
  );
  test(
    'IO write failure removes partial bytes and permits safe retry',
    () async {
      final c = await f.manager.prepareCandidate(
        candidateId: 'io',
        revision: 'r1',
      );
      Stream<List<int>> broken() async* {
        yield [1];
        throw const FileSystemException('injected IO');
      }

      await expectLater(
        f.manager.writeArtifact(c, 'packs/test-0/index.bin', broken()),
        fails(DatasetFailureCode.ioFailure),
      );
      expect(await f.stagedFile(c).exists(), false);
      await f.manager.writeArtifact(
        c,
        'packs/test-0/index.bin',
        Stream.value(f.plans.contents['r1']!['packs/test-0/index.bin']!),
      );
    },
  );
  test(
    'insufficient and unknown storage fail before creating a candidate',
    () async {
      f.space.available = 0;
      await expectLater(
        f.manager.prepareCandidate(candidateId: 'low', revision: 'r1'),
        fails(DatasetFailureCode.insufficientStorage),
      );
      f.space.fail = true;
      await expectLater(
        f.manager.prepareCandidate(candidateId: 'unknown', revision: 'r1'),
        fails(DatasetFailureCode.storageUnavailable),
      );
      expect((await f.manager.recover()).stagedCandidateIds, isEmpty);
    },
  );
  test(
    'abandoned staging is reported but never inferred ready and can be explicitly removed',
    () async {
      final c = await f.candidate('r1');
      await f.manager.close();
      await f.reopen();
      final recovery = await f.manager.recover();
      expect(recovery.activeRevision, null);
      expect(recovery.stagedCandidateIds, [c.id]);
      await f.manager.discardAbandonedCandidate(c.id);
      expect((await f.manager.recover()).stagedCandidateIds, isEmpty);
    },
  );
  test(
    'validator accidental mutation is detected before issuing a receipt',
    () async {
      final c = await f.candidate('r1');
      f.validator.action = (dir, plan) => File(
        '${dir.path}/packs/test-0/index.bin',
      ).writeAsString('changed').then((_) {});
      await expectLater(
        f.manager.verifyCandidate(c),
        fails(DatasetFailureCode.integrityFailed),
      );
      expect(await f.store.read(), null);
    },
  );
  test('failed forced revalidation revokes cached runtime proof', () async {
    await f.activate('r1');
    f.validator.failure = const DatasetFailure(DatasetFailureCode.incompatible);
    expect((await f.manager.recover()).activeRevision, null);
    await expectLater(f.pin(), fails(DatasetFailureCode.incompatible));
    expect((await f.store.read())?.revision, 'r1');
    f.validator.failure = null;
    expect((await f.pin()).revision, 'r1');
  });
  test(
    'cancel retains writer ownership until upstream subscription cleanup drains',
    () async {
      final c = await f.manager.prepareCandidate(
        candidateId: 'drain',
        revision: 'r1',
      );
      final cleanup = Completer<void>();
      final cancelled = Completer<void>();
      final source = StreamController<List<int>>(
        onCancel: () {
          cancelled.complete();
          return cleanup.future;
        },
      );
      final token = DatasetCancellation();
      final writing = f.manager.writeArtifact(
        c,
        'packs/test-0/index.bin',
        source.stream,
        cancellation: token,
      );
      final result = expectLater(writing, fails(DatasetFailureCode.cancelled));
      source.add([1]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      token.cancel();
      await cancelled.future;
      await expectLater(f.manager.close(), fails(DatasetFailureCode.busy));
      cleanup.complete();
      await result;
      await source.close();
      expect(await f.stagedFile(c).exists(), false);
    },
  );
  test(
    'cancelled activation before promotion never changes the pointer',
    () async {
      await f.activate('r1');
      final v = await f.manager.verifyCandidate(await f.candidate('r2'));
      final token = DatasetCancellation()..cancel();
      await expectLater(
        f.manager.commitActiveRevision(v, cancellation: token),
        fails(DatasetFailureCode.cancelled),
      );
      expect((await f.store.read())?.revision, 'r1');
      expect(await f.releasedFile('r2').exists(), false);
    },
  );
  test(
    'cancellation wakes a writer while the input stream is stalled',
    () async {
      final c = await f.manager.prepareCandidate(
        candidateId: 'stalled',
        revision: 'r1',
      );
      final source = StreamController<List<int>>();
      final token = DatasetCancellation();
      final writing = f.manager.writeArtifact(
        c,
        'packs/test-0/index.bin',
        source.stream,
        cancellation: token,
      );
      final result = writing.then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );
      try {
        source.add([1]);
        for (var i = 0; i < 100; i++) {
          if (await f.stagedFile(c).exists() &&
              await f.stagedFile(c).length() == 1) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(await f.stagedFile(c).length(), 1);
        token.cancel();
        expect(
          await result.timeout(const Duration(milliseconds: 300)),
          isA<DatasetFailure>().having(
            (e) => e.code,
            'code',
            DatasetFailureCode.cancelled,
          ),
        );
        expect(await f.stagedFile(c).exists(), false);
        await f.manager.close();
      } finally {
        await source.close();
        await result;
      }
    },
  );
}
