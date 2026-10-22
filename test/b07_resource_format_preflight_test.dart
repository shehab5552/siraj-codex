import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/resource_format_preflight.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

void main() {
  late Directory staging;

  setUp(() async {
    staging = await Directory.systemTemp.createTemp('siraj-format-');
  });
  tearDown(() async => staging.delete(recursive: true));

  Future<ResourceFormatPreflightResult> inspect(
    List<int> bytes,
    ResourceContractKind kind, {
    bool provideHash = true,
  }) async {
    await File('${staging.path}/artifact').writeAsBytes(bytes);
    final hash = await Sha256().hash(bytes);
    final result = await const ArtifactIntegrityValidator().validate(
      stagingRoot: staging,
      relativePath: 'artifact',
      kind: kind,
      expectedSizeBytes: bytes.length,
      expectedSha256: provideHash
          ? hash.bytes
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join()
          : null,
    );
    expect(result, isA<ArtifactIntegrityMatch>());
    return ResourceFormatPreflight.inspect(result as ArtifactIntegrityMatch);
  }

  Uint8List gguf(int version) {
    final bytes = Uint8List(24)..setRange(0, 4, ascii.encode('GGUF'));
    ByteData.sublistView(bytes).setUint32(4, version, Endian.little);
    return bytes;
  }

  for (final version in [2, 3]) {
    test(
      'recognizes the GGUF v$version header without granting model readiness',
      () async {
        final result = await inspect(gguf(version), ResourceContractKind.llm);
        expect(result.status, FormatHeaderStatus.recognizedHeader);
        expect(result.version, '$version');
        expect(
          result.remainingChecks,
          containsAll({
            ResourceValidationCheck.transferComplete,
            ResourceValidationCheck.supportedModelFormat,
            ResourceValidationCheck.runtimeCompatible,
            ResourceValidationCheck.deviceCompatible,
            ResourceValidationCheck.modelLoadProven,
          }),
        );
        expect(
          ResourceValidationRequirements.audit(
            kind: ResourceContractKind.llm,
            reportedPassed: {ResourceValidationCheck.sha256Matched},
          ).evidenceListComplete,
          isFalse,
        );
      },
    );
  }

  test('rejects a GGUF header shorter than the fixed v2/v3 header', () async {
    final result = await inspect(
      gguf(3).sublist(0, 23),
      ResourceContractKind.llm,
    );
    expect(result.status, FormatHeaderStatus.truncatedHeader);
  });

  test('does not recognize a foreign model signature', () async {
    final bytes = gguf(3)..[0] = 0;
    expect(
      (await inspect(bytes, ResourceContractKind.llm)).status,
      FormatHeaderStatus.unrecognizedHeader,
    );
  });

  for (final version in [0, 1, 4, 0x03000000]) {
    test('leaves GGUF version $version to a future format adapter', () async {
      expect(
        (await inspect(gguf(version), ResourceContractKind.llm)).status,
        FormatHeaderStatus.unsupportedHeaderVersion,
      );
    });
  }

  for (final version in ['1.0', '1.7', '2.0']) {
    test(
      'recognizes PDF $version header without claiming readability',
      () async {
        // Header-only file deliberately has no pages, xref, trailer or EOF.
        final result = await inspect(
          ascii.encode('%PDF-$version\n'),
          ResourceContractKind.pdf,
        );
        expect(result.status, FormatHeaderStatus.recognizedHeader);
        expect(result.version, version);
        expect(
          result.remainingChecks,
          contains(ResourceValidationCheck.pdfReadable),
        );
        expect(
          result.remainingChecks,
          isNot(contains(ResourceValidationCheck.sha256Matched)),
        );
      },
    );
  }

  test(
    'does not claim PDF checksum evidence when the catalog provides none',
    () async {
      final result = await inspect(
        ascii.encode('%PDF-1.7\r\n'),
        ResourceContractKind.pdf,
        provideHash: false,
      );
      expect(result.status, FormatHeaderStatus.recognizedHeader);
      expect(result.remainingChecks, {
        ResourceValidationCheck.transferComplete,
        ResourceValidationCheck.pdfReadable,
      });
    },
  );

  test('rejects an incomplete PDF header', () async {
    expect(
      (await inspect(ascii.encode('%PDF-1.'), ResourceContractKind.pdf)).status,
      FormatHeaderStatus.truncatedHeader,
    );
  });

  test('rejects non-PDF content even after its byte hash matches', () async {
    expect(
      (await inspect(
        ascii.encode('<html>error</html>'),
        ResourceContractKind.pdf,
      )).status,
      FormatHeaderStatus.unrecognizedHeader,
    );
  });

  test('rejects a PDF header with no line terminator', () async {
    expect(
      (await inspect(
        ascii.encode('%PDF-1.7x'),
        ResourceContractKind.pdf,
      )).status,
      FormatHeaderStatus.unrecognizedHeader,
    );
  });

  test('does not silently accept an unknown PDF version', () async {
    expect(
      (await inspect(
        ascii.encode('%PDF-9.9\n'),
        ResourceContractKind.pdf,
      )).status,
      FormatHeaderStatus.unsupportedHeaderVersion,
    );
  });

  for (final kind in [
    ResourceContractKind.ragPack,
    ResourceContractKind.ragEmbedding,
  ]) {
    test('${kind.dbKind} still requires its specialized validator', () async {
      final result = await inspect(gguf(3), kind);
      expect(result.status, FormatHeaderStatus.specializedValidatorRequired);
      expect(result.remainingChecks, isNotEmpty);
      expect(
        result.remainingChecks,
        isNot(contains(ResourceValidationCheck.sha256Matched)),
      );
      expect(() => result.remainingChecks.clear(), throwsUnsupportedError);
    });
  }
}
