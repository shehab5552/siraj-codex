import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/download_contracts.dart';
import 'package:siraj/features/resources/resource_download_validator.dart';
import 'package:siraj/features/resources/resource_format_preflight.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

import 'support/litertlm_fixture.dart';

void main() {
  late Directory staging;
  setUp(
    () async => staging = await Directory.systemTemp.createTemp('b08-policy-'),
  );
  tearDown(() async => staging.delete(recursive: true));

  Future<DownloadSpec> writeSpec(
    List<int> bytes,
    ResourceContractKind kind,
  ) async {
    await File('${staging.path}/payload.part').writeAsBytes(bytes);
    final hash = await Sha256().hash(bytes);
    return DownloadSpec(
      resourceId: 'test-only',
      artifactRevision: 'fixture-1',
      kind: kind,
      url: Uri.parse('https://unit-test.invalid/model'),
      destinationKey: 'fixture',
      expectedSize: bytes.length,
      maxBytes: bytes.length,
      expectedSha256: hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
  }

  for (final embedding in [false, true]) {
    test(
      'existing policy uses specialized LiteRT structure for ${embedding ? 'embedding' : 'LLM'}',
      () async {
        final spec = await writeSpec(
          litertlmFixture(embedding: embedding),
          embedding
              ? ResourceContractKind.ragEmbedding
              : ResourceContractKind.llm,
        );
        await expectLater(
          const ResourceDownloadValidator().validate(staging, spec),
          completion(
            isA<ResourceDownloadEvidence>()
                .having(
                  (e) => e.liteRtContainer?.version,
                  'specialized container version',
                  '1.7.0',
                )
                .having(
                  (e) => e.format.status,
                  'limited preflight',
                  FormatHeaderStatus.specializedValidatorRequired,
                )
                .having(
                  (e) => e.liteRtContainer?.remainingChecks.contains(
                    embedding
                        ? ResourceValidationCheck.androidSampleQueryPassed
                        : ResourceValidationCheck.modelLoadProven,
                  ),
                  'runtime proof still required',
                  isTrue,
                ),
          ),
        );
      },
    );
  }

  test('valid SHA does not bypass corrupt LiteRT section validation', () async {
    final spec = await writeSpec(
      litertlmFixture(modelStart: 32768),
      ResourceContractKind.llm,
    );
    await expectLater(
      const ResourceDownloadValidator().validate(staging, spec),
      throwsA(
        isA<DownloadFailure>()
            .having((e) => e.code, 'code', DownloadFailureCode.formatRejected)
            .having(
              (e) => e.detail,
              'structural failure',
              'overlappingSections',
            ),
      ),
    );
  });
}
