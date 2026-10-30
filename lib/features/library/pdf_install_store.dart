import 'dart:io';
import '../resources/artifact_integrity_validator.dart';
import '../resources/download_contracts.dart';
import '../resources/download_staging.dart';
import '../resources/resource_format_preflight.dart';
import '../resources/resource_validation_contracts.dart';
import 'pdf_reader_contracts.dart';

/// App-private immutable catalog identity. All consumers use the application's
/// single coordinator isolate; static leases plus OS locks exclude readers and
/// installers. No SQLite READY/ACTIVE, dataset assembly, or recursive deletion.
class PdfInstallStore {
  const PdfInstallStore(this.appSupport, this.space);
  final Directory appSupport;
  final DownloadSpaceProbe space;
  static final _leases = <String>{};

  static void checkSpec(DownloadSpec spec) {
    if (spec.kind != ResourceContractKind.pdf ||
        spec.expectedSize == null ||
        spec.expectedSize! < 8 ||
        spec.expectedSize! > spec.maxBytes ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(spec.expectedSha256 ?? '') ||
        spec.resourceId.trim().isEmpty ||
        spec.artifactRevision.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(spec.destinationKey) ||
        spec.url.scheme != 'https' ||
        spec.url.host.isEmpty ||
        spec.url.userInfo.isNotEmpty ||
        spec.url.fragment.isNotEmpty) {
      throw const PdfFailure(PdfFailureCode.invalidFile);
    }
  }

  Future<PdfBookLease> acquire(DownloadSpec spec) async {
    checkSpec(spec);
    await _directory(appSupport, create: false);
    final support = await appSupport.resolveSymbolicLinks();
    if (support != appSupport.absolute.path) {
      throw const PdfFailure(PdfFailureCode.unsafePath);
    }
    final parent = Directory('$support/pdf-books-v1');
    await _directory(parent);
    final dir = Directory(
      '${parent.path}/${await DownloadStaging.identity(spec)}',
    );
    await _directory(dir);
    if (!_leases.add(dir.path)) throw const PdfFailure(PdfFailureCode.busy);
    RandomAccessFile? lock;
    try {
      await _inspect(dir);
      lock = await File('${dir.path}/reader.lock').open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      return PdfBookLease._(
        dir,
        spec,
        space,
        lock,
        () => _leases.remove(dir.path),
      );
    } catch (_) {
      await lock?.close();
      _leases.remove(dir.path);
      rethrow;
    }
  }

  static Future<void> _directory(Directory dir, {bool create = true}) async {
    if (create &&
        await FileSystemEntity.type(dir.path, followLinks: false) ==
            FileSystemEntityType.notFound) {
      await dir.create();
    }
    if (await FileSystemEntity.type(dir.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const PdfFailure(PdfFailureCode.unsafePath);
    }
  }

  static Future<void> _inspect(Directory dir) async {
    await _directory(dir, create: false);
    await for (final item in dir.list(followLinks: false)) {
      if (!{
            'book.pdf',
            'candidate.pdf',
            'reader.lock',
          }.contains(item.uri.pathSegments.last) ||
          await FileSystemEntity.type(item.path, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const PdfFailure(PdfFailureCode.unsafePath);
      }
    }
  }
}

class PdfBookLease {
  PdfBookLease._(
    this.directory,
    this.spec,
    this.space,
    this._lock,
    this._onRelease,
  );
  final Directory directory;
  final DownloadSpec spec;
  final DownloadSpaceProbe space;
  final RandomAccessFile _lock;
  final void Function() _onRelease;
  bool _released = false, _prepared = false;
  File get book => File('${directory.path}/book.pdf');
  File get _candidate => File('${directory.path}/candidate.pdf');
  void _requireOpen() {
    if (_released) throw const PdfFailure(PdfFailureCode.closed);
  }

  Future<bool> _valid(String name) async {
    _requireOpen();
    await PdfInstallStore._inspect(directory);
    final proof = await const ArtifactIntegrityValidator().validate(
      stagingRoot: directory,
      relativePath: name,
      kind: ResourceContractKind.pdf,
      expectedSizeBytes: spec.expectedSize,
      expectedSha256: spec.expectedSha256,
    );
    return proof is ArtifactIntegrityMatch &&
        proof.sha256Matched &&
        ResourceFormatPreflight.inspect(proof).status ==
            FormatHeaderStatus.recognizedHeader;
  }

  /// Byte proof only. Library actions separately require native reader proof.
  Future<bool> hasVerifiedBook() => _valid('book.pdf');
  Future<File> prepare(File source) async {
    _requireOpen();
    _prepared = false;
    await PdfInstallStore._inspect(directory);
    if (await hasVerifiedBook()) throw const PdfFailure(PdfFailureCode.busy);
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await source.resolveSymbolicLinks() != source.absolute.path) {
      throw const PdfFailure(PdfFailureCode.unsafePath);
    }
    final free = await space.availableBytes(directory);
    // Reserve the complete second copy plus filesystem/metadata headroom.
    if (free < spec.expectedSize! + 1024 * 1024) {
      throw const DownloadFailure(DownloadFailureCode.insufficientStorage);
    }
    final output = await _candidate.open(mode: FileMode.writeOnly);
    try {
      var count = 0;
      await for (final chunk in source.openRead()) {
        count += chunk.length;
        if (count > spec.expectedSize!) {
          throw const PdfFailure(PdfFailureCode.invalidFile);
        }
        await output.writeFrom(chunk);
      }
      await output.flush();
    } finally {
      await output.close();
    }
    if (!await _valid('candidate.pdf')) {
      throw const PdfFailure(PdfFailureCode.invalidFile);
    }
    _prepared = true;
    return _candidate;
  }

  /// Only called after actual native parse/render proof and successful close.
  /// Atomic rename is within this filesystem. A valid final is never replaced.
  Future<void> promote() async {
    _requireOpen();
    if (!_prepared || !await _valid('candidate.pdf')) {
      throw const PdfFailure(PdfFailureCode.invalidFile);
    }
    if (await hasVerifiedBook()) throw const PdfFailure(PdfFailureCode.busy);
    await _candidate.rename(book.path);
    _prepared = false;
  }

  Future<void> release() async {
    if (_released) return;
    try {
      await _lock.unlock();
    } finally {
      await _lock.close();
      _released = true;
      _onRelease();
    }
  }
}
