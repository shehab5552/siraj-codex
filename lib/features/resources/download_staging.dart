import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'download_contracts.dart';

/// Owns only `downloads-staging-v1/<opaque key>/{payload,provenance,lock}`.
/// Never accepts a release/model/book path or deletes recursively.
/// Use from the application's single download-coordinator isolate.
class DownloadStaging {
  DownloadStaging._(this.directory, this._lock);
  static const metadataLimit = 16 * 1024;
  static final _leases = <String>{};
  final Directory directory;
  final RandomAccessFile _lock;
  File get payload => File('${directory.path}/payload.part');
  File get _metadata => File('${directory.path}/provenance.json');
  File get _temporaryMetadata => File('${directory.path}/provenance.tmp');

  static Future<DownloadStaging> acquire(
    Directory appSupport,
    String key,
  ) async {
    await _requireDirectory(appSupport, create: false);
    final support = await appSupport.resolveSymbolicLinks();
    final parent = Directory('$support/downloads-staging-v1');
    await _requireDirectory(parent);
    final directory = Directory('${parent.path}/$key');
    await _requireDirectory(directory);
    if (!_leases.add(directory.path)) {
      throw const DownloadFailure(DownloadFailureCode.busy);
    }
    RandomAccessFile? lock;
    try {
      await _inspect(directory);
      lock = await File(
        '${directory.path}/writer.lock',
      ).open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      return DownloadStaging._(directory, lock);
    } catch (_) {
      await lock?.close();
      _leases.remove(directory.path);
      rethrow;
    }
  }

  static Future<void> _requireDirectory(
    Directory directory, {
    bool create = true,
  }) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound && create) {
      await directory.create();
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const DownloadFailure(DownloadFailureCode.unsafePath);
    }
  }

  static Future<void> _inspect(Directory directory) async {
    await _requireDirectory(directory, create: false);
    const names = {
      'payload.part',
      'provenance.json',
      'provenance.tmp',
      'writer.lock',
    };
    await for (final entity in directory.list(followLinks: false)) {
      if (!names.contains(entity.uri.pathSegments.last) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const DownloadFailure(DownloadFailureCode.unsafePath);
      }
    }
  }

  Future<bool> get hasLeftovers async =>
      await payload.exists() || await _metadata.exists();

  Future<DownloadCheckpoint?> checkpointFor(DownloadSpec spec) =>
      _checkpointFor(spec, completedOnly: false);
  Future<DownloadCheckpoint?> completedFor(DownloadSpec spec) =>
      _checkpointFor(spec, completedOnly: true);
  Future<DownloadCheckpoint?> _checkpointFor(
    DownloadSpec spec, {
    required bool completedOnly,
  }) async {
    await _inspect(directory);
    if (!await _metadata.exists() || !await payload.exists()) return null;
    try {
      final data = await _readMetadata();
      // Completed candidates belong to the next validation/promotion stage.
      // Even another requested identity cannot authorize their replacement.
      if (!completedOnly &&
          data is Map<String, dynamic> &&
          data['complete'] == true) {
        throw const DownloadFailure(DownloadFailureCode.candidateExists);
      }
      if (!await _validProvenance(data, spec) ||
          data is! Map<String, dynamic> ||
          (completedOnly && data['complete'] != true)) {
        return null;
      }
      final length = data['bytes'] as int;
      final total = data['total'];
      if (length != await payload.length() ||
          data['sha256'] != await hashFile(payload)) {
        return null;
      }
      return DownloadCheckpoint(
        length,
        data['etag'] as String?,
        total as int?,
        data['complete'] as bool,
      );
    } on FormatException {
      return null;
    }
  }

  Future<Object?> _readMetadata() async {
    if (!await _metadata.exists() || await _metadata.length() > metadataLimit) {
      return null;
    }
    final input = await _metadata.open();
    late List<int> bytes;
    try {
      bytes = await input.read(metadataLimit + 1);
    } finally {
      await input.close();
    }
    if (bytes.length > metadataLimit) return null;
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on FormatException {
      return null;
    }
  }

  /// Recovery is explicit, exclusive, and restricted to byte damage whose
  /// completed provenance still exactly identifies the approved artifact.
  /// Foreign or malformed metadata never authorizes deleting a candidate.
  Future<bool> discardCorruptCompletedFor(DownloadSpec spec) async {
    await _inspect(directory);
    final data = await _readMetadata();
    if (!await _validProvenance(data, spec) ||
        data is! Map<String, dynamic> ||
        data['complete'] != true ||
        spec.expectedSize == null ||
        spec.expectedSha256 == null ||
        data['bytes'] != spec.expectedSize ||
        data['sha256'] != spec.expectedSha256!.toLowerCase()) {
      return false;
    }
    if (await payload.exists() &&
        await payload.length() == spec.expectedSize &&
        await hashFile(payload) == spec.expectedSha256!.toLowerCase()) {
      return false;
    }
    await discard();
    return true;
  }

  Future<bool> _validProvenance(Object? data, DownloadSpec spec) async {
    if (data is! Map<String, dynamic> ||
        data.keys.toSet().difference({
          'version',
          'identity',
          'etag',
          'total',
          'bytes',
          'sha256',
          'complete',
        }).isNotEmpty ||
        data.length != 7 ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data['identity'] != await identity(spec) ||
        data['bytes'] is! int ||
        data['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['sha256'] as String) ||
        data['complete'] is! bool ||
        (data['etag'] != null &&
            (data['etag'] is! String ||
                !isStrongEtag(data['etag'] as String)))) {
      return false;
    }
    final length = data['bytes'] as int;
    final total = data['total'];
    return length >= 0 &&
        length <= spec.maxBytes &&
        (total == null ||
            (total is int &&
                total >= length &&
                total <= spec.maxBytes &&
                (spec.expectedSize == null || total == spec.expectedSize)));
  }

  Future<void> saveCheckpoint(
    DownloadSpec spec, {
    required String? etag,
    required int? total,
    bool complete = false,
  }) async {
    await _inspect(directory);
    if (!await payload.exists()) return;
    final bytes = utf8.encode(
      jsonEncode({
        'version': 1,
        'identity': await identity(spec),
        'etag': etag != null && isStrongEtag(etag) ? etag : null,
        'total': total,
        'bytes': await payload.length(),
        'sha256': await hashFile(payload),
        'complete': complete,
      }),
    );
    if (bytes.length > metadataLimit) {
      throw const DownloadFailure(DownloadFailureCode.invalidSpec);
    }
    final output = await _temporaryMetadata.open(mode: FileMode.writeOnly);
    try {
      await output.writeFrom(bytes);
      await output.flush();
    } finally {
      await output.close();
    }
    await _temporaryMetadata.rename(_metadata.path);
  }

  Future<void> invalidateCheckpoint() async {
    await _inspect(directory);
    if (await _metadata.exists()) await _metadata.delete();
    if (await _temporaryMetadata.exists()) await _temporaryMetadata.delete();
  }

  Future<void> discard() async {
    await invalidateCheckpoint();
    if (await payload.exists()) await payload.delete();
  }

  Future<RandomAccessFile> openPayload({required bool append}) async {
    await _inspect(directory);
    return payload.open(
      mode: append ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
  }

  Future<void> release() async {
    try {
      await _lock.unlock();
    } finally {
      try {
        await _lock.close();
      } finally {
        _leases.remove(directory.path);
      }
    }
  }

  static bool isStrongEtag(String value) =>
      value.length <= 512 && RegExp(r'^"[\x21\x23-\x7e]*"$').hasMatch(value);

  static Future<String> identity(DownloadSpec spec) async {
    final hash = await Sha256().hash(
      utf8.encode(
        jsonEncode([
          spec.resourceId,
          spec.artifactRevision,
          spec.kind.dbKind,
          spec.url.toString(),
          spec.destinationKey,
          spec.expectedSize,
          spec.expectedSha256?.toLowerCase(),
          spec.maxBytes,
        ]),
      ),
    );
    return _hex(hash.bytes);
  }

  static Future<String> hashFile(File file) async {
    final sink = Sha256().toSync().newHashSink();
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return _hex((await sink.hash()).bytes);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

class DownloadCheckpoint {
  const DownloadCheckpoint(this.bytes, this.etag, this.total, this.complete);
  final int bytes;
  final String? etag;
  final int? total;
  final bool complete;
}
