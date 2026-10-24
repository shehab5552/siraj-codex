import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dataset_release_contracts.dart';
import 'dataset_release_manager.dart';
import 'download_contracts.dart';
import 'download_service.dart';
import 'resource_download_validator.dart';

enum DatasetPreparationPhase {
  idle,
  preparing,
  downloading,
  assembling,
  validating,
  activating,
  active,
  cancelled,
  failed,
}

/// The approved catalog adapter binds HTTPS artifacts to the manager's exact
/// six-component plan. This API supplies no production URLs or archive format.
abstract interface class ApprovedDatasetDownloads {
  Future<List<DatasetDownloadPart>?> resolve(DatasetReleasePlan plan);
}

class UnavailableDatasetDownloads implements ApprovedDatasetDownloads {
  const UnavailableDatasetDownloads();
  @override
  Future<List<DatasetDownloadPart>?> resolve(DatasetReleasePlan plan) async =>
      null;
}

class DatasetDownloadPart {
  const DatasetDownloadPart({
    required this.componentId,
    required this.spec,
    required this.assembler,
  });
  final String componentId;
  final DownloadSpec spec;
  final DatasetFileAssembler assembler;
}

typedef DatasetArtifactWriter =
    Future<void> Function(String relativePath, Stream<List<int>> bytes);

abstract interface class DatasetFileAssembler {
  Future<void> assemble({
    required File downloaded,
    required DownloadSpec spec,
    required DatasetComponent component,
    required DatasetArtifactWriter write,
  });
}

/// Only a catalog-declared, exact single-file component is supported here.
/// Multi-file archives need a separately approved safe extractor adapter.
class DirectDatasetFileAssembler implements DatasetFileAssembler {
  const DirectDatasetFileAssembler();
  @override
  Future<void> assemble({
    required File downloaded,
    required DownloadSpec spec,
    required DatasetComponent component,
    required DatasetArtifactWriter write,
  }) async {
    if (component.files.length != 1 ||
        spec.expectedSize != component.files.single.sizeBytes ||
        spec.expectedSha256?.toLowerCase() !=
            component.files.single.sha256.toLowerCase()) {
      throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    }
    await write(component.files.single.path, downloaded.openRead());
  }
}

/// One consent, one existing HTTPS transport, one existing atomic manager.
/// A downloaded file is never READY. Only successful runtime validation and a
/// durable pointer commit can produce `active`. Resources are device-scoped.
class DatasetPreparationCoordinator extends ChangeNotifier {
  DatasetPreparationCoordinator({
    required this.downloads,
    required this.manager,
    this.catalog = const UnavailableDatasetDownloads(),
  });
  final DownloadService<ResourceDownloadEvidence> downloads;
  final DatasetReleaseManager manager;
  final ApprovedDatasetDownloads catalog;
  DatasetPreparationPhase phase = DatasetPreparationPhase.idle;
  Object? failure;
  bool cleanupDeferred = false;
  bool _busy = false, _disposed = false;
  bool get busy => _busy;
  int _completedBytes = 0, totalBytes = 0;
  DownloadHandle<ResourceDownloadEvidence>? _handle;
  DatasetCancellation? _cancellation;
  Completer<void>? _completion;
  int get downloadedBytes =>
      _completedBytes +
      (_handle == null ? 0 : downloads.progress(_handle!).downloadedBytes);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _set(DatasetPreparationPhase value) {
    phase = value;
    _notify();
  }

  Future<String> prepareAndActivate({
    required String revision,
    required String candidateId,
    required bool consented,
  }) async {
    if (_disposed) throw const DatasetFailure(DatasetFailureCode.closed);
    if (_busy) throw const DatasetFailure(DatasetFailureCode.busy);
    if (!consented) throw const DatasetFailure(DatasetFailureCode.invalidPlan);
    _busy = true;
    _completion = Completer<void>();
    _cancellation = DatasetCancellation();
    failure = null;
    cleanupDeferred = false;
    _completedBytes = 0;
    totalBytes = 0;
    StagedDatasetCandidate? candidate;
    bool committed = false;
    try {
      _set(DatasetPreparationPhase.preparing);
      candidate = await manager.prepareCandidate(
        candidateId: candidateId,
        revision: revision,
      );
      _cancellation!.check();
      final plan = candidate.plan;
      final parts = await catalog.resolve(plan);
      _cancellation!.check();
      if (parts == null ||
          parts.length != plan.components.length ||
          parts.map((p) => p.componentId).toSet().length != parts.length ||
          parts.map((p) => p.spec.destinationKey).toSet().length !=
              parts.length) {
        throw const DatasetFailure(DatasetFailureCode.invalidPlan);
      }
      for (final part in parts) {
        final matches = plan.components.where(
          (component) => component.id == part.componentId,
        );
        if (matches.length != 1 ||
            part.spec.kind != matches.single.kind ||
            part.spec.artifactRevision != revision ||
            part.spec.expectedSize == null ||
            part.spec.expectedSha256 == null) {
          throw const DatasetFailure(DatasetFailureCode.invalidPlan);
        }
      }
      totalBytes = parts.fold(0, (sum, part) => sum + part.spec.expectedSize!);
      _notify();
      for (final part in parts) {
        _cancellation!.check();
        final component = plan.components.singleWhere(
          (component) => component.id == part.componentId,
        );
        Future<void> assemble(File file) async {
          _cancellation!.check();
          _set(DatasetPreparationPhase.assembling);
          await part.assembler.assemble(
            downloaded: file,
            spec: part.spec,
            component: component,
            write: (path, bytes) {
              if (!component.files.any((f) => f.path == path)) {
                throw const DatasetFailure(DatasetFailureCode.unsafePath);
              }
              return manager.writeArtifact(
                candidate!,
                path,
                bytes,
                cancellation: _cancellation,
              );
            },
          );
        }

        var reused = false;
        try {
          await downloads.withCompletedArtifact(part.spec, assemble);
          reused = true;
        } on DownloadFailure catch (error) {
          if (error.code != DownloadFailureCode.candidateUnavailable) rethrow;
        }
        if (!reused) {
          _cancellation!.check();
          _set(DatasetPreparationPhase.downloading);
          final handle = _handle = downloads.start(part.spec);
          final timer = Timer.periodic(
            const Duration(milliseconds: 100),
            (_) => _notify(),
          );
          late DownloadResult<ResourceDownloadEvidence> result;
          try {
            result = await handle.result;
          } finally {
            timer.cancel();
          }
          _handle = null;
          _cancellation!.check();
          if (result.state != DownloadState.downloaded) {
            throw result.failure ??
                const DatasetFailure(DatasetFailureCode.cancelled);
          }
          await downloads.withCompletedArtifact(part.spec, assemble);
        }
        _completedBytes += part.spec.expectedSize!;
        _notify();
      }
      _cancellation!.check();
      _set(DatasetPreparationPhase.validating);
      final verified = await manager.verifyCandidate(
        candidate,
        cancellation: _cancellation,
      );
      _cancellation!.check();
      _set(DatasetPreparationPhase.activating);
      final active = await manager.commitActiveRevision(
        verified,
        cancellation: _cancellation,
      );
      // No cancellation check after the durable commit boundary.
      committed = true;
      _set(DatasetPreparationPhase.active);
      return active;
    } catch (error) {
      failure = error is DownloadFailure || error is DatasetFailure
          ? error
          : const DatasetFailure(DatasetFailureCode.ioFailure);
      _set(
        error is DatasetFailure && error.code == DatasetFailureCode.cancelled
            ? DatasetPreparationPhase.cancelled
            : DatasetPreparationPhase.failed,
      );
      Error.throwWithStackTrace(failure!, StackTrace.current);
    } finally {
      if (!committed && candidate != null) {
        try {
          await manager.discardCandidate(candidate);
        } catch (_) {
          // A promoted orphan or ambiguous DB commit must never be deleted.
          cleanupDeferred = true;
        }
      }
      _handle = null;
      _busy = false;
      _completion!.complete();
      _notify();
    }
  }

  Future<void> cancel() async {
    _cancellation?.cancel();
    final handle = _handle;
    if (handle != null) await downloads.cancel(handle);
    await _completion?.future;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancel());
    super.dispose();
  }
}
