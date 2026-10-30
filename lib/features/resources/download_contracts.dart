import 'dart:io';

import 'resource_validation_contracts.dart';

/// Catalog-owned identity. No production URL, revision or size is invented here.
class DownloadSpec {
  const DownloadSpec({
    required this.resourceId,
    required this.artifactRevision,
    required this.kind,
    required this.url,
    required this.destinationKey,
    required this.maxBytes,
    this.expectedSize,
    this.expectedSha256,
  });
  final String resourceId;
  final String artifactRevision;
  final ResourceContractKind kind;
  final Uri url;
  final String destinationKey;
  final int maxBytes;
  final int? expectedSize;
  final String? expectedSha256;
}

/// Transport states only. Downloaded is not resource READY or dataset ACTIVE.
enum DownloadState {
  queued,
  downloading,
  paused,
  verifying,
  downloaded,
  failed,
  cancelled,
}

enum DownloadRestartReason {
  untrustedProvenance,
  rangeIgnored,
  validatorChanged,
  rangeNotSatisfiable,
}

enum DownloadFailureCode {
  invalidSpec,
  unsafePath,
  busy,
  candidateExists,
  candidateUnavailable,
  insufficientStorage,
  storageUnavailable,
  ioFailure,
  networkFailure,
  httpFailure,
  invalidRange,
  sizeMismatch,
  integrityFailure,
  formatRejected,
  verificationFailure,
  protocolFailure,
}

class DownloadFailure implements Exception {
  const DownloadFailure(
    this.code, {
    this.hostname,
    this.httpStatus,
    this.detail,
    this.osErrorCode,
  });
  final DownloadFailureCode code;
  final String? hostname;
  final int? httpStatus;
  final String? detail;
  final int? osErrorCode;
}

class DownloadProgress {
  const DownloadProgress(this.state, this.downloadedBytes, this.totalBytes);
  final DownloadState state;
  final int downloadedBytes;
  final int? totalBytes;
}

class DownloadResult<T> {
  const DownloadResult({
    required this.state,
    this.failure,
    this.evidence,
    this.stagedFile,
    this.resumedFrom = 0,
    this.restartReason,
  });
  final DownloadState state;
  final DownloadFailure? failure;
  final T? evidence;
  final File? stagedFile;

  /// Reused prefix bytes; zero for a successfully restarted full transfer.
  final int resumedFrom;
  final DownloadRestartReason? restartReason;
}

/// OS storage boundary. Unknown availability must fail closed.
abstract interface class DownloadSpaceProbe {
  Future<int> availableBytes(Directory directory);
}

/// Independent resource policy. Transport never selects a model or sets READY.
abstract interface class StagedDownloadValidator<T> {
  void checkSpec(DownloadSpec spec);
  Future<T> validate(Directory stagingDirectory, DownloadSpec spec);
}
