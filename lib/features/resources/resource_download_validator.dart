import 'dart:convert';
import 'dart:io';

import 'artifact_integrity_validator.dart';
import 'download_contracts.dart';
import 'litertlm_format_validator.dart';
import 'resource_format_preflight.dart';
import 'resource_validation_contracts.dart';

class ResourceDownloadEvidence {
  const ResourceDownloadEvidence(
    this.integrity,
    this.format, {
    this.liteRtContainer,
  });
  final ArtifactIntegrityMatch integrity;
  final ResourceFormatPreflightResult format;
  final LiteRtLmFormatMatch? liteRtContainer;
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
    LiteRtLmFormatMatch? container;
    if ({
          ResourceContractKind.llm,
          ResourceContractKind.ragEmbedding,
        }.contains(spec.kind) &&
        match.prefix.length >= 8 &&
        ascii.decode(match.prefix.take(8).toList(), allowInvalid: true) ==
            'LITERTLM') {
      final specialized = await const LiteRtLmFormatValidator().inspect(
        stagingRoot: stagingDirectory,
        artifact: match,
      );
      if (specialized is LiteRtLmFormatFailure) {
        throw DownloadFailure(
          DownloadFailureCode.formatRejected,
          detail: specialized.code.name,
        );
      }
      container = specialized as LiteRtLmFormatMatch;
    }
    return ResourceDownloadEvidence(match, format, liteRtContainer: container);
  }
}
