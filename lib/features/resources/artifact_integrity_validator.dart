import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'resource_validation_contracts.dart';

enum ArtifactIntegrityFailureCode {
  invalidExpectation,
  missingRequiredHash,
  unsafePath,
  missingFile,
  sizeMismatch,
  hashMismatch,
  fileChanged,
  ioFailure,
}

sealed class ArtifactIntegrityResult {
  const ArtifactIntegrityResult();
}

final class ArtifactIntegrityFailure extends ArtifactIntegrityResult {
  const ArtifactIntegrityFailure(this.code);
  final ArtifactIntegrityFailureCode code;
}

/// Byte-integrity evidence only. Never authorizes READY or activation.
final class ArtifactIntegrityMatch extends ArtifactIntegrityResult {
  ArtifactIntegrityMatch._({
    required this.kind,
    required this.relativePath,
    required this.bytesRead,
    required this.sha256,
    required this.sha256Matched,
    required List<int> prefix,
  }) : prefix = List.unmodifiable(prefix);

  final ResourceContractKind kind;
  final String relativePath;
  final int bytesRead;
  final String sha256;
  final bool sha256Matched;
  final List<int> prefix;
}

class ArtifactIntegrityValidator {
  const ArtifactIntegrityValidator();

  /// Reads only an app-private staging tree with no concurrent writers.
  /// Expectations must come from a trusted catalog, not the downloaded file.
  ///
  /// Rejects links/traversal and detects ordinary changes during reading, but
  /// Dart path checks are not an OS-level no-follow/locking primitive. Callers
  /// must serialize writes and keep staging inaccessible to external writers.
  /// No network, extraction, database writes, promotion or runtime loading.
  Future<ArtifactIntegrityResult> validate({
    required Directory stagingRoot,
    required String relativePath,
    required ResourceContractKind kind,
    int? expectedSizeBytes,
    String? expectedSha256,
  }) async {
    if ((expectedSizeBytes != null && expectedSizeBytes < 0) ||
        (expectedSha256 != null &&
            !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha256))) {
      return const ArtifactIntegrityFailure(
        ArtifactIntegrityFailureCode.invalidExpectation,
      );
    }
    if (expectedSha256 == null && kind != ResourceContractKind.pdf) {
      return const ArtifactIntegrityFailure(
        ArtifactIntegrityFailureCode.missingRequiredHash,
      );
    }

    // Use a deliberately unambiguous relative-path grammar on all platforms.
    final segments = relativePath.split('/');
    if (relativePath.contains(RegExp(r'[\\:\x00]')) ||
        segments.any((part) => part.isEmpty || part == '.' || part == '..')) {
      return const ArtifactIntegrityFailure(
        ArtifactIntegrityFailureCode.unsafePath,
      );
    }

    try {
      final rootType = await FileSystemEntity.type(
        stagingRoot.path,
        followLinks: false,
      );
      if (rootType == FileSystemEntityType.notFound) {
        return const ArtifactIntegrityFailure(
          ArtifactIntegrityFailureCode.missingFile,
        );
      }
      if (rootType != FileSystemEntityType.directory) {
        return const ArtifactIntegrityFailure(
          ArtifactIntegrityFailureCode.unsafePath,
        );
      }
      final rootPath = await stagingRoot.resolveSymbolicLinks();
      final pathFailure = await _checkPath(rootPath, segments);
      if (pathFailure != null) return ArtifactIntegrityFailure(pathFailure);
      final file = File('$rootPath/${segments.join('/')}');
      final before = await file.stat();
      if (expectedSizeBytes != null && before.size != expectedSizeBytes) {
        return const ArtifactIntegrityFailure(
          ArtifactIntegrityFailureCode.sizeMismatch,
        );
      }

      final handle = await file.open();
      try {
        // Explicit pure Dart streaming sink: do not buffer a multi-GB model
        // through a platform implementation of HashAlgorithm.newHashSink().
        final sink = Sha256().toSync().newHashSink();
        final prefix = <int>[];
        var bytesRead = 0;
        while (true) {
          final chunk = await handle.read(64 * 1024);
          if (chunk.isEmpty) break;
          bytesRead += chunk.length;
          if (bytesRead > before.size) {
            return const ArtifactIntegrityFailure(
              ArtifactIntegrityFailureCode.fileChanged,
            );
          }
          if (prefix.length < 24) {
            prefix.addAll(chunk.take(24 - prefix.length));
          }
          sink.add(chunk);
        }
        sink.close();
        final digest = await sink.hash();

        final after = await file.stat();
        final finalPathFailure = await _checkPath(rootPath, segments);
        if (finalPathFailure != null) {
          return ArtifactIntegrityFailure(finalPathFailure);
        }
        if (await stagingRoot.resolveSymbolicLinks() != rootPath ||
            before.size != bytesRead ||
            await handle.length() != bytesRead ||
            before.size != after.size ||
            before.modified != after.modified ||
            before.changed != after.changed) {
          return const ArtifactIntegrityFailure(
            ArtifactIntegrityFailureCode.fileChanged,
          );
        }
        final sha256 = digest.bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();
        if (expectedSha256 != null && sha256 != expectedSha256.toLowerCase()) {
          return const ArtifactIntegrityFailure(
            ArtifactIntegrityFailureCode.hashMismatch,
          );
        }
        return ArtifactIntegrityMatch._(
          kind: kind,
          relativePath: relativePath,
          bytesRead: bytesRead,
          sha256: sha256,
          sha256Matched: expectedSha256 != null,
          prefix: prefix,
        );
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return const ArtifactIntegrityFailure(
        ArtifactIntegrityFailureCode.ioFailure,
      );
    }
  }

  Future<ArtifactIntegrityFailureCode?> _checkPath(
    String rootPath,
    List<String> segments,
  ) async {
    var path = rootPath;
    for (var index = 0; index < segments.length; index++) {
      path = '$path/${segments[index]}';
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        return ArtifactIntegrityFailureCode.missingFile;
      }
      final expected = index == segments.length - 1
          ? FileSystemEntityType.file
          : FileSystemEntityType.directory;
      if (type != expected) return ArtifactIntegrityFailureCode.unsafePath;
    }
    return null;
  }
}
