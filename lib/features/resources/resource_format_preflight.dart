import 'dart:convert';
import 'dart:typed_data';

import 'artifact_integrity_validator.dart';
import 'resource_validation_contracts.dart';

enum FormatHeaderStatus {
  recognizedHeader,
  truncatedHeader,
  unrecognizedHeader,
  unsupportedHeaderVersion,
  specializedValidatorRequired,
}

class ResourceFormatPreflightResult {
  ResourceFormatPreflightResult._({
    required this.status,
    this.version,
    required Set<ResourceValidationCheck> remainingChecks,
  }) : remainingChecks = Set.unmodifiable(remainingChecks);

  final FormatHeaderStatus status;
  final String? version;

  /// Header recognition never supplies format/runtime/readability evidence.
  /// Only a matched catalog SHA-256 is removed from this inventory.
  final Set<ResourceValidationCheck> remainingChecks;
}

/// Bounded signature preflight on bytes captured during integrity checking.
/// Does not parse tensors, metadata, PDF objects, archives or embedding config.
/// A recognized header can belong to a corrupt or unusable file.
class ResourceFormatPreflight {
  const ResourceFormatPreflight._();

  static ResourceFormatPreflightResult inspect(
    ArtifactIntegrityMatch artifact,
  ) {
    final remaining = ResourceValidationRequirements.forKind(
      artifact.kind,
      pdfCatalogHashProvided: artifact.sha256Matched,
    ).toSet();
    if (artifact.sha256Matched) {
      remaining.remove(ResourceValidationCheck.sha256Matched);
    }
    final (status, version) = switch (artifact.kind) {
      ResourceContractKind.llm => _gguf(artifact.prefix),
      ResourceContractKind.pdf => _pdf(artifact.prefix),
      ResourceContractKind.ragPack || ResourceContractKind.ragEmbedding => (
        FormatHeaderStatus.specializedValidatorRequired,
        null,
      ),
    };
    return ResourceFormatPreflightResult._(
      status: status,
      version: version,
      remainingChecks: remaining,
    );
  }

  static (FormatHeaderStatus, String?) _gguf(List<int> prefix) {
    // GGUF v2/v3 fixed header: magic, uint32 version, two uint64 counts.
    // Recognition is not selection of a supported production model/runtime.
    if (prefix.length < 24) return (FormatHeaderStatus.truncatedHeader, null);
    if (ascii.decode(prefix.take(4).toList(), allowInvalid: true) != 'GGUF') {
      return (FormatHeaderStatus.unrecognizedHeader, null);
    }
    final version = ByteData.sublistView(
      Uint8List.fromList(prefix),
    ).getUint32(4, Endian.little);
    return (
      version == 2 || version == 3
          ? FormatHeaderStatus.recognizedHeader
          : FormatHeaderStatus.unsupportedHeaderVersion,
      '$version',
    );
  }

  static (FormatHeaderStatus, String?) _pdf(List<int> prefix) {
    if (prefix.length < 9) return (FormatHeaderStatus.truncatedHeader, null);
    if (ascii.decode(prefix.take(5).toList(), allowInvalid: true) != '%PDF-' ||
        (prefix[8] != 10 && prefix[8] != 13)) {
      return (FormatHeaderStatus.unrecognizedHeader, null);
    }
    final version = ascii.decode(prefix.sublist(5, 8), allowInvalid: true);
    final known = RegExp(r'^1\.[0-7]$').hasMatch(version) || version == '2.0';
    return (
      known
          ? FormatHeaderStatus.recognizedHeader
          : FormatHeaderStatus.unsupportedHeaderVersion,
      version,
    );
  }
}
