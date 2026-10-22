import 'dart:io';

import 'artifact_integrity_validator.dart';
import 'download_contracts.dart';
import 'resource_format_preflight.dart';
import 'resource_validation_contracts.dart';

class ResourceDownloadEvidence {
  const ResourceDownloadEvidence(this.integrity, this.format);
  final ArtifactIntegrityMatch integrity;
  final ResourceFormatPreflightResult format;
}

class ResourceDownloadValidator
    implements StagedDownloadValidator<ResourceDownloadEvidence> {
  const ResourceDownloadValidator();
  @override
  void checkSpec(DownloadSpec spec) {
    if (spec.kind != ResourceContractKind.pdf && spec.expectedSha256 == null) {
      throw const DownloadFailure(
        DownloadFailureCode.invalidSpec,
        detail: 'missingRequiredHash',
      );
    }
  }

  @override
  Future<ResourceDownloadEvidence> validate(
    Directory stagingDirectory,
    DownloadSpec spec,
  ) async {
    final result = await const ArtifactIntegrityValidator().validate(
      stagingRoot: stagingDirectory,
      relativePath: 'payload.part',
      kind: spec.kind,
      expectedSizeBytes: spec.expectedSize,
      expectedSha256: spec.expectedSha256,
    );
    if (result is ArtifactIntegrityFailure) {
      throw DownloadFailure(
        DownloadFailureCode.integrityFailure,
        detail: result.code.name,
      );
    }
    final match = result as ArtifactIntegrityMatch;
    final format = ResourceFormatPreflight.inspect(match);
    if (format.status != FormatHeaderStatus.recognizedHeader &&
        format.status != FormatHeaderStatus.specializedValidatorRequired) {
      throw DownloadFailure(
        DownloadFailureCode.formatRejected,
        detail: format.status.name,
      );
    }
    return ResourceDownloadEvidence(match, format);
  }
}
