import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import '../../data/dataset_pointer_store.dart';
import 'artifact_integrity_validator.dart';
import 'dataset_release_contracts.dart';
import 'download_contracts.dart';
import 'download_storage_space.dart';
import 'rag_candidate_contract.dart';
import 'resource_validation_contracts.dart';

class StagedDatasetCandidate {
  StagedDatasetCandidate._(this.id, this._plan, this._fingerprint);
  final String id;
  final DatasetReleasePlan _plan;
  final String _fingerprint;
  bool _sealed = false, _promoted = false;
  int _verification = 0;
  String get revision => _plan.revision;
  DatasetReleasePlan get plan => _plan;
}

/// Only the manager can create a receipt; it is bound to this exact candidate,
/// approved plan and verification attempt, never a caller-supplied checklist.
class VerifiedDatasetCandidate {
  VerifiedDatasetCandidate._(
    this._candidate,
    this._verification,
    this._previous,
  );
  final StagedDatasetCandidate _candidate;
  final int _verification;
  final DatasetPointer? _previous;
  String get revision => _candidate.revision;
}

/// All pack/index/embedding paths resolve beneath one immutable directory.
/// Call release only after the reader and its native work have actually drained.
class RevisionPinnedHandle {
  RevisionPinnedHandle._(this.plan, this.directory, this._release);
  final DatasetReleasePlan plan;
  final Directory directory;
  final void Function() _release;
  bool _released = false;
  String get revision => plan.revision;
  bool get isReleased => _released;
  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

/// Single app coordinator isolate, with exclusive app-private root ownership.
/// No external writers may mutate its staging/releases tree. Rename has no copy
/// fallback: cross-filesystem failure leaves the previous pointer untouched.
class DatasetReleaseManager {
  DatasetReleaseManager._(
    this._root,
    this._lock,
    this._store,
    this._plans,
    this._validator,
    this._space,
  );
  static final _owners = <String>{};
  final Directory _root;
  final RandomAccessFile _lock;
  final DatasetPointerStore _store;
  final ApprovedDatasetPlans _plans;
  final DatasetRuntimeValidator _validator;
  final DownloadSpaceProbe _space;
  final _candidates = <StagedDatasetCandidate>{};
  final _pins = <String, int>{};
  final _validatedPlans = <String, String>{};
  bool _busy = false, _closed = false;

  static Future<DatasetReleaseManager> open({
    required Directory appSupport,
    required DatasetPointerStore store,
    ApprovedDatasetPlans plans = const UnavailableDatasetPlans(),
    DatasetRuntimeValidator validator =
        const UnavailableDatasetRuntimeValidator(),
    DownloadSpaceProbe space = const AndroidDownloadSpaceProbe(),
  }) async {
    await _directory(appSupport, create: false);
    final support = await appSupport.resolveSymbolicLinks();
    final root = Directory('$support/rag');
    await _directory(root);
    if (!_owners.add(root.path)) {
      throw const DatasetFailure(DatasetFailureCode.busy);
    }
    RandomAccessFile? lock;
    try {
      await _directory(Directory('${root.path}/staging'));
      await _directory(Directory('${root.path}/releases'));
      final file = File('${root.path}/release-manager.lock');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const DatasetFailure(DatasetFailureCode.unsafePath);
      }
      lock = await file.open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      return DatasetReleaseManager._(
        root,
        lock,
        store,
        plans,
        validator,
        space,
      );
    } catch (error) {
      await lock?.close();
      _owners.remove(root.path);
      if (error is FileSystemException) {
        throw DatasetFailure(
          error.osError?.errorCode == 28
              ? DatasetFailureCode.insufficientStorage
              : DatasetFailureCode.ioFailure,
        );
      }
      rethrow;
    }
  }

  static bool _segment(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value);
  static bool _relative(String value) =>
      !value.contains(RegExp(r'[\\:\x00-\x1f]')) &&
      value.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..');
  static Future<void> _directory(Directory value, {bool create = true}) async {
    final type = await FileSystemEntity.type(value.path, followLinks: false);
    if (type == FileSystemEntityType.notFound && create) await value.create();
    if (await FileSystemEntity.type(value.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const DatasetFailure(DatasetFailureCode.unsafePath);
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_closed) throw const DatasetFailure(DatasetFailureCode.closed);
    if (_busy) throw const DatasetFailure(DatasetFailureCode.busy);
    _busy = true;
    try {
      await _directory(_root, create: false);
      await _directory(Directory('${_root.path}/staging'), create: false);
      await _directory(Directory('${_root.path}/releases'), create: false);
      return await action();
    } on DatasetFailure {
      rethrow;
    } on FileSystemException catch (e) {
      throw DatasetFailure(
        e.osError?.errorCode == 28
            ? DatasetFailureCode.insufficientStorage
            : DatasetFailureCode.ioFailure,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _requireSpace(Directory directory, int bytes) async {
    int available;
    try {
      available = await _space.availableBytes(directory);
    } catch (_) {
      throw const DatasetFailure(DatasetFailureCode.storageUnavailable);
    }
    if (available < 0) {
      throw const DatasetFailure(DatasetFailureCode.storageUnavailable);
    }
    if (available < bytes) {
      throw const DatasetFailure(DatasetFailureCode.insufficientStorage);
    }
  }

  Future<DatasetReleasePlan> _approved(String revision) async {
    if (!_segment(revision)) {
      throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    }
    DatasetReleasePlan? plan;
    try {
      plan = await _plans.resolve(revision);
    } on DatasetFailure {
      rethrow;
    } catch (_) {
      throw const DatasetFailure(DatasetFailureCode.validatorUnavailable);
    }
    if (plan == null) {
      throw const DatasetFailure(DatasetFailureCode.validatorUnavailable);
    }
    if (plan.revision != revision ||
        !RagCandidateContract.preflight(plan.declaration).structureConsistent) {
      throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    }
    final packs = plan.components
        .where((c) => c.kind == ResourceContractKind.ragPack)
        .toList();
    final embeddings = plan.components
        .where((c) => c.kind == ResourceContractKind.ragEmbedding)
        .toList();
    final expected = plan.declaration.expectedSubjectIds.toSet();
    if (plan.components.length != 6 ||
        packs.length != 5 ||
        embeddings.length != 1 ||
        packs.map((c) => c.id).toSet().length != 5 ||
        !packs.every((c) => expected.contains(c.id)) ||
        embeddings.single.id != plan.declaration.sharedEmbedding!.modelId) {
      throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    }
    final paths = <String>{};
    for (final component in plan.components) {
      if (component.files.isEmpty) {
        throw const DatasetFailure(DatasetFailureCode.invalidPlan);
      }
      for (final file in component.files) {
        if (!_relative(file.path) ||
            file.sizeBytes <= 0 ||
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(file.sha256) ||
            !paths.add(file.path) ||
            (file.path.startsWith('shared_embedding/') !=
                (component.kind == ResourceContractKind.ragEmbedding))) {
          throw const DatasetFailure(DatasetFailureCode.invalidPlan);
        }
      }
    }
    if (paths.any(
      (p) => paths.any((other) => other != p && other.startsWith('$p/')),
    )) {
      throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    }
    return plan;
  }

  Future<String> _fingerprint(DatasetReleasePlan plan) async {
    final d = plan.declaration;
    final components = plan.components.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final packs = d.packs.toList()
      ..sort((a, b) => a.subjectId.compareTo(b.subjectId));
    final subjects = d.expectedSubjectIds.toList()..sort();
    final e = d.sharedEmbedding!;
    final values = [
      d.datasetRevision,
      subjects,
      d.expectedIndexType,
      d.expectedIndexVersion,
      [
        e.datasetRevision,
        e.modelId,
        e.vectorDimensions,
        e.tokenizerId,
        e.pooling,
        e.normalization,
      ],
      for (final p in packs)
        [
          p.subjectId,
          p.datasetRevision,
          p.embeddingModelId,
          p.vectorDimensions,
          p.indexType,
          p.indexVersion,
        ],
      for (final c in components)
        [
          c.kind.dbKind,
          c.id,
          for (final f
              in (c.files.toList()..sort((a, b) => a.path.compareTo(b.path))))
            [f.path, f.sizeBytes, f.sha256.toLowerCase()],
        ],
    ];
    final digest = await Sha256().hash(utf8.encode(jsonEncode(values)));
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Directory _staging(StagedDatasetCandidate c) =>
      Directory('${_root.path}/staging/${c.id}');
  Directory _release(String revision) =>
      Directory('${_root.path}/releases/$revision');
  void _owns(StagedDatasetCandidate c) {
    if (!_candidates.contains(c) || c._promoted) {
      throw const DatasetFailure(DatasetFailureCode.candidateChanged);
    }
  }

  Future<StagedDatasetCandidate> prepareCandidate({
    required String candidateId,
    required String revision,
  }) => _exclusive(() async {
    if (!_segment(candidateId)) {
      throw const DatasetFailure(DatasetFailureCode.unsafePath);
    }
    final plan = await _approved(revision);
    await _requireSpace(
      _root,
      plan.components
          .expand((c) => c.files)
          .fold<int>(0, (sum, f) => sum + f.sizeBytes),
    );
    final dir = Directory('${_root.path}/staging/$candidateId');
    if (await FileSystemEntity.type(dir.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const DatasetFailure(DatasetFailureCode.releaseExists);
    }
    await dir.create();
    final c = StagedDatasetCandidate._(
      candidateId,
      plan,
      await _fingerprint(plan),
    );
    _candidates.add(c);
    return c;
  });

  /// Assembly boundary for a trusted extractor/copy adapter after B07 transport.
  /// Owns the writer through stream completion; no concurrent verify or promote.
  Future<void> writeArtifact(
    StagedDatasetCandidate c,
    String relativePath,
    Stream<List<int>> bytes, {
    DatasetCancellation? cancellation,
  }) => _exclusive(() async {
    _owns(c);
    if (c._sealed || !_relative(relativePath)) {
      throw const DatasetFailure(DatasetFailureCode.unsafePath);
    }
    final files = c._plan.components
        .expand((component) => component.files)
        .where((f) => f.path == relativePath);
    if (files.length != 1) {
      throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    }
    final expected = files.single;
    final base = _staging(c);
    await _directory(base, create: false);
    await _requireSpace(base, expected.sizeBytes);
    var parent = base.path;
    final parts = relativePath.split('/');
    for (final part in parts.take(parts.length - 1)) {
      parent = '$parent/$part';
      await _directory(Directory(parent));
    }
    final file = File('${base.path}/$relativePath');
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const DatasetFailure(DatasetFailureCode.releaseExists);
    }
    cancellation?.check();
    final output = await file.open(mode: FileMode.writeOnly);
    final iterator = StreamIterator<List<int>>(bytes);
    final cancelled = cancellation?.whenCancelled.then<bool>(
      (_) => throw const DatasetFailure(DatasetFailureCode.cancelled),
    );
    var length = 0;
    try {
      try {
        while (true) {
          final next = iterator.moveNext();
          final hasNext = cancelled == null
              ? await next
              : await Future.any([next, cancelled]);
          if (!hasNext) break;
          cancellation?.check();
          final chunk = iterator.current;
          length += chunk.length;
          if (length > expected.sizeBytes) {
            throw const DatasetFailure(DatasetFailureCode.integrityFailed);
          }
          await output.writeFrom(chunk);
        }
        cancellation?.check();
        if (length != expected.sizeBytes) {
          throw const DatasetFailure(DatasetFailureCode.incomplete);
        }
        await output.flush();
      } finally {
        // Retain writer ownership until subscription cleanup actually drains.
        await iterator.cancel();
      }
    } catch (_) {
      await output.close();
      await file.delete();
      rethrow;
    }
    await output.close();
  });

  Future<void> _tree(Directory directory, Set<String> expected) async {
    await _directory(directory, create: false);
    final directories = <String>{};
    for (final path in expected) {
      final parts = path.split('/');
      for (var i = 1; i < parts.length; i++) {
        directories.add(parts.take(i).join('/'));
      }
    }
    final found = <String>{};
    Future<void> walk(Directory dir, String prefix) async {
      await for (final entity in dir.list(followLinks: false)) {
        final name = entity.uri.pathSegments.where((p) => p.isNotEmpty).last;
        final relative = '$prefix$name';
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory &&
            directories.contains(relative)) {
          await walk(Directory(entity.path), '$relative/');
        } else if (type == FileSystemEntityType.file &&
            expected.contains(relative)) {
          found.add(relative);
        } else {
          throw const DatasetFailure(DatasetFailureCode.unsafePath);
        }
      }
    }

    await walk(directory, '');
    if (found.length != expected.length) {
      throw const DatasetFailure(DatasetFailureCode.incomplete);
    }
  }

  Future<void> _bytes(Directory directory, DatasetReleasePlan plan) async {
    await _tree(
      directory,
      plan.components.expand((c) => c.files).map((f) => f.path).toSet(),
    );
    for (final component in plan.components) {
      for (final file in component.files) {
        final result = await const ArtifactIntegrityValidator().validate(
          stagingRoot: directory,
          relativePath: file.path,
          kind: component.kind,
          expectedSizeBytes: file.sizeBytes,
          expectedSha256: file.sha256,
        );
        if (result is! ArtifactIntegrityMatch) {
          throw const DatasetFailure(DatasetFailureCode.integrityFailed);
        }
      }
    }
  }

  Future<void> _runtime(Directory dir, DatasetReleasePlan plan) async {
    if (_pins.isNotEmpty && !_validator.supportsPinnedValidation) {
      throw const DatasetFailure(DatasetFailureCode.pinned);
    }
    try {
      await _validator.validate(dir, plan);
    } on DatasetFailure {
      rethrow;
    } catch (_) {
      throw const DatasetFailure(DatasetFailureCode.validationFailed);
    }
    // Validators are trusted read-only adapters; detect accidental byte writes.
    await _bytes(dir, plan);
  }

  Future<VerifiedDatasetCandidate> verifyCandidate(
    StagedDatasetCandidate c, {
    DatasetCancellation? cancellation,
  }) => _exclusive(() async {
    _owns(c);
    c._sealed = true;
    c._verification++;
    cancellation?.check();
    final approved = await _approved(c.revision);
    if (await _fingerprint(approved) != c._fingerprint) {
      throw const DatasetFailure(DatasetFailureCode.candidateChanged);
    }
    await _bytes(_staging(c), approved);
    cancellation?.check();
    await _runtime(_staging(c), approved);
    cancellation?.check();
    final previous = await _readPointer();
    return VerifiedDatasetCandidate._(c, c._verification, previous);
  });

  Future<DatasetPointer?> _readPointer() async {
    try {
      return await _store.read();
    } catch (_) {
      throw const DatasetFailure(DatasetFailureCode.databaseFailure);
    }
  }

  Future<String> commitActiveRevision(
    VerifiedDatasetCandidate verified, {
    DatasetCancellation? cancellation,
  }) => _exclusive(() async {
    final c = verified._candidate;
    _owns(c);
    if (c._verification != verified._verification) {
      throw const DatasetFailure(DatasetFailureCode.candidateChanged);
    }
    final approved = await _approved(c.revision);
    if (await _fingerprint(approved) != c._fingerprint) {
      throw const DatasetFailure(DatasetFailureCode.candidateChanged);
    }
    cancellation?.check();
    await _bytes(_staging(c), approved);
    final release = _release(c.revision);
    if (await FileSystemEntity.type(release.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const DatasetFailure(DatasetFailureCode.releaseExists);
    }
    cancellation?.check();
    await _staging(c).rename(release.path);
    c._promoted = true;
    _candidates.remove(c);
    // After promotion, any failure leaves an unreferenced immutable directory.
    // Never remove it here: an ambiguous commit must not delete active data.
    await _bytes(release, approved);
    cancellation?.check();
    try {
      await _store.commitPromoted(
        expected: verified._previous,
        revision: c.revision,
        path: release.path,
        nowUtc: DateTime.now().toUtc().toIso8601String(),
      );
    } on DatasetPointerConflict {
      throw const DatasetFailure(DatasetFailureCode.pointerConflict);
    } catch (_) {
      throw const DatasetFailure(DatasetFailureCode.databaseFailure);
    }
    // Do not report cancellation after a durable commit as a failed activation.
    _validatedPlans[c.revision] = c._fingerprint;
    return c.revision;
  });

  Future<DatasetReleasePlan> _validatedPointer(
    DatasetPointer? pointer, {
    bool forceRuntime = false,
  }) async {
    if (forceRuntime) _validatedPlans.remove(pointer?.revision);
    try {
      if (pointer == null ||
          pointer.state != 'READY' ||
          pointer.revision == null ||
          !_segment(pointer.revision!) ||
          pointer.path != _release(pointer.revision!).path) {
        throw const DatasetFailure(DatasetFailureCode.sourceUnavailable);
      }
      final approved = await _approved(pointer.revision!);
      await _bytes(_release(approved.revision), approved);
      final fingerprint = await _fingerprint(approved);
      if (forceRuntime || _validatedPlans[approved.revision] != fingerprint) {
        await _runtime(_release(approved.revision), approved);
        _validatedPlans[approved.revision] = fingerprint;
      }
      return approved;
    } catch (_) {
      _validatedPlans.remove(pointer?.revision);
      rethrow;
    }
  }

  Future<RevisionPinnedHandle> openHandle() => _exclusive(() async {
    final plan = await _validatedPointer(await _readPointer());
    _pins.update(plan.revision, (n) => n + 1, ifAbsent: () => 1);
    return RevisionPinnedHandle._(plan, _release(plan.revision), () {
      final count = _pins[plan.revision]!;
      if (count == 1) {
        _pins.remove(plan.revision);
      } else {
        _pins[plan.revision] = count - 1;
      }
    });
  });

  Future<DatasetRecovery> recover() => _exclusive(() async {
    final pointer = await _readPointer();
    String? active;
    DatasetFailureCode? failure;
    if (pointer != null) {
      try {
        active = (await _validatedPointer(
          pointer,
          forceRuntime: true,
        )).revision;
      } on DatasetFailure catch (e) {
        failure = e.code;
      }
    }
    final unreferenced = <String>[];
    await for (final entity in Directory(
      '${_root.path}/releases',
    ).list(followLinks: false)) {
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const DatasetFailure(DatasetFailureCode.unsafePath);
      }
      final name = entity.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (!_segment(name)) {
        throw const DatasetFailure(DatasetFailureCode.unsafePath);
      }
      if (name != pointer?.revision) unreferenced.add(name);
    }
    unreferenced.sort();
    final staged = <String>[];
    await for (final entity in Directory(
      '${_root.path}/staging',
    ).list(followLinks: false)) {
      final name = entity.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (!_segment(name) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        throw const DatasetFailure(DatasetFailureCode.unsafePath);
      }
      staged.add(name);
    }
    staged.sort();
    return DatasetRecovery(
      activeRevision: active,
      failure: failure,
      unreferencedRevisions: unreferenced,
      stagedCandidateIds: staged,
    );
  });

  Future<void> _deleteRegularTree(Directory dir) async {
    await _directory(dir, create: false);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file &&
          type != FileSystemEntityType.directory) {
        throw const DatasetFailure(DatasetFailureCode.unsafePath);
      }
    }
    await dir.delete(recursive: true);
  }

  Future<void> discardCandidate(StagedDatasetCandidate c) =>
      _exclusive(() async {
        _owns(c);
        await _deleteRegularTree(_staging(c));
        _candidates.remove(c);
      });
  Future<void> removeUnreferenced(String revision) => _exclusive(() async {
    if (!_segment(revision)) {
      throw const DatasetFailure(DatasetFailureCode.unsafePath);
    }
    final pointer = await _readPointer();
    if (pointer?.revision == revision ||
        pointer?.path == _release(revision).path ||
        _pins.containsKey(revision)) {
      throw const DatasetFailure(DatasetFailureCode.pinned);
    }
    await _deleteRegularTree(_release(revision));
  });

  Future<void> discardAbandonedCandidate(String candidateId) => _exclusive(
    () async {
      if (!_segment(candidateId)) {
        throw const DatasetFailure(DatasetFailureCode.unsafePath);
      }
      if (_candidates.any((c) => c.id == candidateId)) {
        throw const DatasetFailure(DatasetFailureCode.busy);
      }
      await _deleteRegularTree(Directory('${_root.path}/staging/$candidateId'));
    },
  );

  Future<void> close() async {
    if (_closed) return;
    if (_busy) throw const DatasetFailure(DatasetFailureCode.busy);
    if (_pins.isNotEmpty) throw const DatasetFailure(DatasetFailureCode.pinned);
    _closed = true;
    try {
      await _lock.unlock();
    } finally {
      try {
        await _lock.close();
      } finally {
        _owners.remove(_root.path);
      }
    }
  }
}
