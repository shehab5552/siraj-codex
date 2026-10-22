import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

const abcSha256 =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

void main() {
  late Directory staging;
  late Directory outside;
  const validator = ArtifactIntegrityValidator();

  setUp(() async {
    staging = await Directory.systemTemp.createTemp('siraj-integrity-');
    outside = await Directory.systemTemp.createTemp('siraj-outside-');
    await File('${staging.path}/artifact').writeAsString('abc');
  });

  tearDown(() async {
    await staging.delete(recursive: true);
    await outside.delete(recursive: true);
  });

  Future<ArtifactIntegrityResult> validate({
    Directory? root,
    String path = 'artifact',
    int? size = 3,
    String? sha256 = abcSha256,
    ResourceContractKind kind = ResourceContractKind.llm,
  }) => validator.validate(
    stagingRoot: root ?? staging,
    relativePath: path,
    expectedSizeBytes: size,
    expectedSha256: sha256,
    kind: kind,
  );

  void expectFailure(
    ArtifactIntegrityResult result,
    ArtifactIntegrityFailureCode code,
  ) {
    expect(result, isA<ArtifactIntegrityFailure>());
    expect((result as ArtifactIntegrityFailure).code, code);
  }

  test(
    'matches the published SHA-256 abc vector without changing the file',
    () async {
      final result = await validate();
      expect(result, isA<ArtifactIntegrityMatch>());
      final match = result as ArtifactIntegrityMatch;
      expect(match.sha256, abcSha256);
      expect(match.sha256Matched, isTrue);
      expect(match.bytesRead, 3);
      expect(match.prefix, [97, 98, 99]);
      expect(await File('${staging.path}/artifact').readAsString(), 'abc');
    },
  );

  test(
    'compares uppercase catalog hex without changing digest bytes',
    () async {
      expect(
        await validate(sha256: abcSha256.toUpperCase()),
        isA<ArtifactIntegrityMatch>(),
      );
    },
  );

  test('rejects a same-size corrupted artifact', () async {
    await File('${staging.path}/artifact').writeAsString('abd');
    expectFailure(await validate(), ArtifactIntegrityFailureCode.hashMismatch);
  });

  for (final size in [2, 4]) {
    test('rejects declared size $size for three observed bytes', () async {
      expectFailure(
        await validate(size: size),
        ArtifactIntegrityFailureCode.sizeMismatch,
      );
    });
  }

  for (final kind in ResourceContractKind.values.where(
    (kind) => kind != ResourceContractKind.pdf,
  )) {
    test(
      '${kind.dbKind} cannot be checked without a trusted catalog hash',
      () async {
        expectFailure(
          await validate(kind: kind, sha256: null),
          ArtifactIntegrityFailureCode.missingRequiredHash,
        );
      },
    );
  }

  test(
    'PDF without catalog hash reports observed bytes, never a hash match',
    () async {
      final result = await validate(
        kind: ResourceContractKind.pdf,
        sha256: null,
        size: null,
      );
      expect(result, isA<ArtifactIntegrityMatch>());
      expect((result as ArtifactIntegrityMatch).sha256Matched, isFalse);
      expect(result.sha256, abcSha256);
    },
  );

  test('PDF catalog hash is enforced when supplied', () async {
    expectFailure(
      await validate(kind: ResourceContractKind.pdf, sha256: '0' * 64),
      ArtifactIntegrityFailureCode.hashMismatch,
    );
  });

  test(
    'rejects malformed hashes rather than treating them as absent',
    () async {
      for (final hash in [
        '',
        'g' * 64,
        '0' * 63,
        ' $abcSha256',
        '$abcSha256\n',
      ]) {
        expectFailure(
          await validate(sha256: hash),
          ArtifactIntegrityFailureCode.invalidExpectation,
        );
      }
    },
  );

  test('rejects negative declared size', () async {
    expectFailure(
      await validate(size: -1),
      ArtifactIntegrityFailureCode.invalidExpectation,
    );
  });

  test(
    'hash verification works when the catalog does not declare size',
    () async {
      expect(await validate(size: null), isA<ArtifactIntegrityMatch>());
    },
  );

  test('missing artifact is a typed failure', () async {
    expectFailure(
      await validate(path: 'missing'),
      ArtifactIntegrityFailureCode.missingFile,
    );
  });

  test(
    'empty bytes can match integrity but do not prove a usable resource',
    () async {
      await File('${staging.path}/artifact').writeAsBytes([]);
      final result = await validate(
        size: 0,
        sha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(result, isA<ArtifactIntegrityMatch>());
      expect((result as ArtifactIntegrityMatch).bytesRead, 0);
      expect(result.prefix, isEmpty);
    },
  );

  test('missing staging root is a typed failure', () async {
    expectFailure(
      await validate(root: Directory('${staging.path}/missing')),
      ArtifactIntegrityFailureCode.missingFile,
    );
  });

  test(
    'rejects traversal, absolute paths and ambiguous path segments',
    () async {
      for (final path in [
        '',
        '../artifact',
        '/artifact',
        'a/../artifact',
        './artifact',
        'a//artifact',
        'a\\artifact',
        'C:/artifact',
        'artifact/',
        'a\u0000b',
      ]) {
        expectFailure(
          await validate(path: path),
          ArtifactIntegrityFailureCode.unsafePath,
        );
      }
    },
  );

  test('rejects a directory in place of an artifact', () async {
    await Directory('${staging.path}/folder').create();
    expectFailure(
      await validate(path: 'folder'),
      ArtifactIntegrityFailureCode.unsafePath,
    );
  });

  test('rejects a file symlink even when its target hash matches', () async {
    await File('${outside.path}/artifact').writeAsString('abc');
    await Link('${staging.path}/linked').create('${outside.path}/artifact');
    expectFailure(
      await validate(path: 'linked'),
      ArtifactIntegrityFailureCode.unsafePath,
    );
  });

  test('rejects an intermediate directory symlink', () async {
    await File('${outside.path}/artifact').writeAsString('abc');
    await Link('${staging.path}/linked').create(outside.path);
    expectFailure(
      await validate(path: 'linked/artifact'),
      ArtifactIntegrityFailureCode.unsafePath,
    );
  });

  test('rejects a symlink supplied as the staging root', () async {
    await Link('${outside.path}/root').create(staging.path);
    expectFailure(
      await validate(root: Directory('${outside.path}/root')),
      ArtifactIntegrityFailureCode.unsafePath,
    );
  });

  test('accepts an ordinary nested file under the staging root', () async {
    await Directory('${staging.path}/nested').create();
    await File('${staging.path}/nested/artifact').writeAsString('abc');
    expect(
      await validate(path: 'nested/artifact'),
      isA<ArtifactIntegrityMatch>(),
    );
  });

  test(
    'streams a multi-buffer artifact and retains only a bounded immutable prefix',
    () async {
      final bytes = List<int>.generate(1024 * 1024 + 7, (index) => index % 251);
      final hash = await Sha256().hash(bytes);
      final expected = hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      await File('${staging.path}/artifact').writeAsBytes(bytes);
      final result =
          await validate(size: bytes.length, sha256: expected)
              as ArtifactIntegrityMatch;
      expect(result.bytesRead, bytes.length);
      expect(result.sha256, expected);
      expect(result.prefix, bytes.take(24).toList());
      expect(() => result.prefix.add(0), throwsUnsupportedError);
    },
  );
}
