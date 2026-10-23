import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/dataset_pointer_store.dart';
import 'package:siraj/features/resources/dataset_release_contracts.dart';
import 'package:siraj/features/resources/dataset_release_manager.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/rag_candidate_contract.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

/// Synthetic bytes/configuration for filesystem/SQLite control-flow tests only.
/// Nothing here is a Biology fixture, Android sample query, or production data.
class TestDatasetPlans implements ApprovedDatasetPlans {
  final plans = <String, DatasetReleasePlan>{};
  final contents = <String, Map<String, List<int>>>{};
  @override
  Future<DatasetReleasePlan?> resolve(String revision) async => plans[revision];
  Future<void> add(String revision) async {
    final files = <String, List<int>>{
      for (var i = 0; i < 5; i++)
        'packs/test-$i/index.bin': utf8.encode('SYNTHETIC $revision pack $i'),
      'shared_embedding/test-model.bin': utf8.encode(
        'SYNTHETIC $revision shared model',
      ),
    };
    final artifacts = <String, DatasetArtifact>{};
    for (final e in files.entries) {
      final hash = await Sha256().hash(e.value);
      artifacts[e.key] = DatasetArtifact(
        path: e.key,
        sizeBytes: e.value.length,
        sha256: hash.bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      );
    }
    plans[revision] = DatasetReleasePlan(
      declaration: RagCandidateDeclaration(
        datasetRevision: revision,
        expectedSubjectIds: [for (var i = 0; i < 5; i++) 'test-$i'],
        packs: [
          for (var i = 0; i < 5; i++)
            RagPackDeclaration(
              subjectId: 'test-$i',
              datasetRevision: revision,
              embeddingModelId: 'test-shared',
              vectorDimensions: 3,
              indexType: 'TEST_INDEX',
              indexVersion: 'test-v1',
            ),
        ],
        sharedEmbedding: SharedEmbeddingDeclaration(
          datasetRevision: revision,
          modelId: 'test-shared',
          vectorDimensions: 3,
          tokenizerId: 'TEST_TOKENIZER',
          pooling: 'TEST_POOL',
          normalization: 'TEST_NORM',
        ),
        expectedIndexType: 'TEST_INDEX',
        expectedIndexVersion: 'test-v1',
      ),
      components: [
        for (var i = 0; i < 5; i++)
          DatasetComponent(
            id: 'test-$i',
            kind: ResourceContractKind.ragPack,
            files: [artifacts['packs/test-$i/index.bin']!],
          ),
        DatasetComponent(
          id: 'test-shared',
          kind: ResourceContractKind.ragEmbedding,
          files: [artifacts['shared_embedding/test-model.bin']!],
        ),
      ],
    );
    contents[revision] = files;
  }
}

class TestDatasetValidator implements DatasetRuntimeValidator {
  @override
  bool supportsPinnedValidation = true;
  DatasetFailure? failure;
  Completer<void>? paused;
  final calls = <String>[];
  Future<void> Function(Directory, DatasetReleasePlan)? action;
  @override
  Future<void> validate(Directory dir, DatasetReleasePlan plan) async {
    calls.add(plan.revision);
    if (paused != null) await paused!.future;
    if (failure != null) throw failure!;
    if (action != null) await action!(dir, plan);
    // Deliberately a test double, NOT actual index/embedding/Android validation.
  }
}

class TestDatasetSpace implements DownloadSpaceProbe {
  int available = 1024 * 1024;
  bool fail = false;
  @override
  Future<int> availableBytes(Directory directory) async {
    if (fail) {
      throw const DownloadFailure(DownloadFailureCode.storageUnavailable);
    }
    return available;
  }
}

class DatasetFixture {
  late Directory support;
  late AppDatabase db;
  late DatasetPointerStore store;
  late DatasetReleaseManager manager;
  final plans = TestDatasetPlans();
  final validator = TestDatasetValidator();
  final space = TestDatasetSpace();
  final handles = <RevisionPinnedHandle>[];
  var serial = 0;
  Future<void> initialize({bool persistent = false}) async {
    support = await Directory.systemTemp.createTemp('siraj-b12-test-');
    db = AppDatabase.forTesting(
      persistent
          ? NativeDatabase(File('${support.path}/state.sqlite'))
          : NativeDatabase.memory(),
    );
    store = DatasetPointerStore(db);
    await plans.add('r1');
    await plans.add('r2');
    await reopen();
  }

  Future<void> reopenDatabase() async {
    await manager.close();
    await db.close();
    db = AppDatabase.forTesting(
      NativeDatabase(File('${support.path}/state.sqlite')),
    );
    store = DatasetPointerStore(db);
    await reopen();
  }

  Future<void> reopen({DatasetRuntimeValidator? selectedValidator}) async {
    manager = await DatasetReleaseManager.open(
      appSupport: support,
      store: store,
      plans: plans,
      validator: selectedValidator ?? validator,
      space: space,
    );
  }

  Future<StagedDatasetCandidate> candidate(String revision) async {
    final c = await manager.prepareCandidate(
      candidateId: 'candidate-${serial++}',
      revision: revision,
    );
    for (final e in plans.contents[revision]!.entries) {
      await manager.writeArtifact(c, e.key, Stream.value(e.value));
    }
    return c;
  }

  Future<void> activate(String revision) async {
    await manager.commitActiveRevision(
      await manager.verifyCandidate(await candidate(revision)),
    );
  }

  Future<RevisionPinnedHandle> pin() async {
    final h = await manager.openHandle();
    handles.add(h);
    return h;
  }

  File releasedFile(String revision) =>
      File('${support.path}/rag/releases/$revision/packs/test-0/index.bin');
  File stagedFile(StagedDatasetCandidate c) =>
      File('${support.path}/rag/staging/${c.id}/packs/test-0/index.bin');
  Future<void> close() async {
    for (final h in handles) {
      h.release();
    }
    await manager.close();
    await db.close();
    await support.delete(recursive: true);
  }
}
