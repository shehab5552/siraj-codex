import 'dart:async';
import 'dart:io';
import 'rag_candidate_contract.dart';
import 'resource_validation_contracts.dart';

enum DatasetFailureCode {
  invalidPlan,
  unsafePath,
  busy,
  closed,
  incomplete,
  integrityFailed,
  validatorUnavailable,
  incompatible,
  validationFailed,
  candidateChanged,
  releaseExists,
  ioFailure,
  pointerConflict,
  databaseFailure,
  sourceUnavailable,
  pinned,
  cancelled,
  insufficientStorage,
  storageUnavailable,
}

class DatasetFailure implements Exception {
  const DatasetFailure(this.code);
  final DatasetFailureCode code;
}

/// Resolved from the approved catalog, never inferred from downloaded metadata.
class DatasetArtifact {
  const DatasetArtifact({
    required this.path,
    required this.sizeBytes,
    required this.sha256,
  });
  final String path, sha256;
  final int sizeBytes;
}

class DatasetComponent {
  DatasetComponent({
    required this.id,
    required this.kind,
    required Iterable<DatasetArtifact> files,
  }) : files = List.unmodifiable(files);
  final String id;
  final ResourceContractKind kind;
  final List<DatasetArtifact> files;
}

class DatasetReleasePlan {
  DatasetReleasePlan({
    required this.declaration,
    required Iterable<DatasetComponent> components,
  }) : components = List.unmodifiable(components);
  final RagCandidateDeclaration declaration;
  final List<DatasetComponent> components;
  String get revision => declaration.datasetRevision;
}

abstract interface class ApprovedDatasetPlans {
  Future<DatasetReleasePlan?> resolve(String revision);
}

class UnavailableDatasetPlans implements ApprovedDatasetPlans {
  const UnavailableDatasetPlans();
  @override
  Future<DatasetReleasePlan?> resolve(String revision) async => null;
}

/// Trusted A/C adapter validates actual schema/chunk refs/indexes and the exact
/// shared model/tokenizer/pooling/normalization/dimensions, and executes the
/// required Android sample query. Success is not a caller-supplied checklist.
/// It must drain/release its temporary runtime work before completing/throwing.
/// It must never replace/unload resources held by existing revision handles.
abstract interface class DatasetRuntimeValidator {
  bool get supportsPinnedValidation;
  Future<void> validate(
    Directory immutableCandidate,
    DatasetReleasePlan approvedPlan,
  );
}

class UnavailableDatasetRuntimeValidator implements DatasetRuntimeValidator {
  const UnavailableDatasetRuntimeValidator();
  @override
  bool get supportsPinnedValidation => false;
  @override
  Future<void> validate(
    Directory immutableCandidate,
    DatasetReleasePlan approvedPlan,
  ) async =>
      throw const DatasetFailure(DatasetFailureCode.validatorUnavailable);
}

class DatasetCancellation {
  bool _cancelled = false;
  final _signal = Completer<void>();
  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _signal.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _signal.complete();
  }

  void check() {
    if (_cancelled) throw const DatasetFailure(DatasetFailureCode.cancelled);
  }
}

class DatasetRecovery {
  DatasetRecovery({
    required this.activeRevision,
    required this.failure,
    required Iterable<String> unreferencedRevisions,
    required Iterable<String> stagedCandidateIds,
  }) : unreferencedRevisions = List.unmodifiable(unreferencedRevisions),
       stagedCandidateIds = List.unmodifiable(stagedCandidateIds);

  /// Non-null only after validating the current pointer, all files and runtime.
  final String? activeRevision;
  final DatasetFailureCode? failure;

  /// Unreferenced is not permission to delete: old readers may still be pinned.
  final List<String> unreferencedRevisions;
  final List<String> stagedCandidateIds;
}
