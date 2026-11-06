import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/litertlm_format_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

import 'support/litertlm_fixture.dart';

void main() {
  late Directory staging;
  setUp(
    () async => staging = await Directory.systemTemp.createTemp('b08-format-'),
  );
  tearDown(() async => staging.delete(recursive: true));

  Future<LiteRtLmFormatResult> inspect(
    List<int> bytes, {
    bool embedding = false,
  }) async {
    await File('${staging.path}/candidate').writeAsBytes(bytes);
    final digest = await Sha256().hash(bytes);
    final proof = await const ArtifactIntegrityValidator().validate(
      stagingRoot: staging,
      relativePath: 'candidate',
      kind: embedding
          ? ResourceContractKind.ragEmbedding
          : ResourceContractKind.llm,
      expectedSizeBytes: bytes.length,
      expectedSha256: digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
    return const LiteRtLmFormatValidator().inspect(
      stagingRoot: staging,
      artifact: proof as ArtifactIntegrityMatch,
    );
  }

  for (final embedding in [false, true]) {
    test(
      'parses official-schema synthetic ${embedding ? 'embedding' : 'LLM'} container without readiness',
      () async {
        final result = await inspect(
          litertlmFixture(embedding: embedding),
          embedding: embedding,
        );
        expect(result, isA<LiteRtLmFormatMatch>());
        final match = result as LiteRtLmFormatMatch;
        expect(match.version, '1.7.0');
        expect(match.sectionCount, 3);
        expect(
          match.remainingChecks,
          contains(
            embedding
                ? ResourceValidationCheck.androidSampleQueryPassed
                : ResourceValidationCheck.modelLoadProven,
          ),
        );
      },
    );
  }

  test('parses bounded HF tokenizer zlib and UTF8 JSON structurally', () async {
    expect(
      await inspect(litertlmFixture(hfTokenizer: true)),
      isA<LiteRtLmFormatMatch>(),
    );
  });

  test(
    'rejects wrong decoded length, oversized tokenizer and bad zlib',
    () async {
      for (final bytes in [
        litertlmFixture(hfTokenizer: true, declaredTokenizerSize: 3),
        litertlmFixture(
          hfTokenizer: true,
          declaredTokenizerSize: 32 * 1024 * 1024,
        ),
        litertlmFixture(hfTokenizer: true, corruptTokenizer: true),
      ]) {
        final result = await inspect(bytes) as LiteRtLmFormatFailure;
        expect(result.code, LiteRtLmFormatFailureCode.invalidSectionPayload);
      }
    },
  );

  test('rejects invalid tokenizer UTF8 and JSON', () async {
    for (final raw in [
      [123, 34, 120, 34, 58, 34, 255, 34, 125],
      [123],
      [91, 93],
    ]) {
      expect(
        await inspect(litertlmFixture(hfTokenizer: true, tokenizerJson: raw)),
        isA<LiteRtLmFormatFailure>(),
      );
    }
  });

  test('rejects truncated prefix and bad magic', () async {
    expect(await inspect([1, 2]), isA<LiteRtLmFormatFailure>());
    final bytes = litertlmFixture()..[0] = 0;
    expect(await inspect(bytes), isA<LiteRtLmFormatFailure>());
  });

  test('rejects unknown container version', () async {
    final bytes = litertlmFixture();
    ByteData.sublistView(bytes).setUint32(8, 2, Endian.little);
    final result = await inspect(bytes) as LiteRtLmFormatFailure;
    expect(result.code, LiteRtLmFormatFailureCode.unsupportedVersion);
  });

  test('rejects corrupt root offset and oversized header', () async {
    for (final mode in ['root', 'header']) {
      final bytes = litertlmFixture();
      final data = ByteData.sublistView(bytes);
      if (mode == 'root') data.setUint32(32, 0xfffffff0, Endian.little);
      if (mode == 'header') data.setUint64(24, 2 * 1024 * 1024, Endian.little);
      expect(await inspect(bytes), isA<LiteRtLmFormatFailure>());
    }
  });

  test('rejects sections outside truncated file', () async {
    expect(
      await inspect(litertlmFixture().sublist(0, 1024)),
      isA<LiteRtLmFormatFailure>(),
    );
  });

  test('rejects unaligned and overlapping sections', () async {
    expect(
      await inspect(litertlmFixture(metadataStart: 16385)),
      isA<LiteRtLmFormatFailure>(),
    );
    expect(
      await inspect(litertlmFixture(modelStart: 32768)),
      isA<LiteRtLmFormatFailure>(),
    );
  });

  test('rejects missing metadata or tokenizer or TFLite model', () async {
    for (final type in [5, 4, 3]) {
      final result =
          await inspect(litertlmFixture(omitTypes: {type}))
              as LiteRtLmFormatFailure;
      expect(result.code, LiteRtLmFormatFailureCode.missingSection);
    }
  });

  test('rejects artifact role inconsistent with embedded metadata', () async {
    expect(
      await inspect(litertlmFixture(embedding: true)),
      isA<LiteRtLmFormatFailure>(),
    );
  });

  test('rejects invalid TFLite identifier and malformed protobuf', () async {
    for (final index in [49156, 16384]) {
      final bytes = litertlmFixture()..[index] = 0xff;
      expect(await inspect(bytes), isA<LiteRtLmFormatFailure>());
    }
  });

  test(
    'rejects explicitly newer runtime requirement without version bypass',
    () async {
      final result =
          await inspect(litertlmFixture(minimumRuntime: '99.0.0'))
              as LiteRtLmFormatFailure;
      expect(result.code, LiteRtLmFormatFailureCode.unsupportedRuntime);
    },
  );

  test(
    'retains absent minimum runtime as unknown, accepts older declared minimum structurally',
    () async {
      expect(
        (await inspect(litertlmFixture()) as LiteRtLmFormatMatch)
            .minimumRuntimeVersion,
        isNull,
      );
      expect(
        (await inspect(litertlmFixture(minimumRuntime: '0.18.0'))
                as LiteRtLmFormatMatch)
            .minimumRuntimeVersion,
        '0.18.0',
      );
    },
  );
}
