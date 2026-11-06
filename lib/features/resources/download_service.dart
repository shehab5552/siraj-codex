import 'dart:async';
import 'dart:io';

import 'download_contracts.dart';
import 'download_staging.dart';

class DownloadHandle<T> {
  DownloadHandle._(this._owner, this.spec);
  final Object _owner;
  final DownloadSpec spec;
  late Future<DownloadResult<T>> _result;
  Future<DownloadResult<T>> get result => _result;
  bool _running = false;
  int _controls = 0;
  DownloadState _state = DownloadState.queued;
  DownloadState? _stop;
  int _bytes = 0;
  int? _total;
  int _resumedFrom = 0;
  DownloadRestartReason? _restartReason;
  HttpClient? _client;
  HttpClientRequest? _request;
  int? _httpStatus;
}

/// HTTPS transport into an exclusive, app-private staging namespace.
/// All callers must use the app's single coordinator isolate. A completed
/// candidate is immutable to this API; activation belongs to ResourceManager.
class DownloadService<T> {
  DownloadService({
    required this.appSupportDirectory,
    required this.spaceProbe,
    required this.validator,
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
  }) : _clientFactory = clientFactory ?? HttpClient.new;
  final Directory appSupportDirectory;
  final DownloadSpaceProbe spaceProbe;
  final StagedDownloadValidator<T> validator;
  final HttpClient Function() _clientFactory;
  final Duration timeout;

  DownloadHandle<T> start(DownloadSpec spec) {
    final handle = DownloadHandle<T>._(this, spec);
    _launch(handle);
    return handle;
  }

  DownloadProgress progress(DownloadHandle<T> handle) {
    _requireOwner(handle);
    return DownloadProgress(handle._state, handle._bytes, handle._total);
  }

  Future<DownloadResult<T>> retry(DownloadHandle<T> handle) =>
      resumeOrRestart(handle);

  Future<DownloadResult<T>> resumeOrRestart(DownloadHandle<T> handle) {
    _requireOwner(handle);
    if (handle._running || handle._controls > 0) {
      return Future.value(
        _failure(
          handle,
          const DownloadFailure(DownloadFailureCode.busy),
          preserveState: true,
        ),
      );
    }
    if (handle._state == DownloadState.downloaded) return handle.result;
    handle._stop = null;
    _launch(handle);
    return handle.result;
  }

  Future<DownloadResult<T>> pause(DownloadHandle<T> handle) =>
      _stop(handle, DownloadState.paused);
  Future<DownloadResult<T>> cancel(DownloadHandle<T> handle) =>
      _stop(handle, DownloadState.cancelled);

  Future<DownloadResult<T>> _stop(
    DownloadHandle<T> handle,
    DownloadState state,
  ) async {
    _requireOwner(handle);
    handle._controls++;
    try {
      if (handle._state == DownloadState.downloaded) return await handle.result;
      // Cancellation dominates a simultaneous pause request.
      if (handle._stop != DownloadState.cancelled) handle._stop = state;
      handle._request?.abort();
      handle._client?.close(force: true);
      if (!handle._running) _launch(handle);
      final result = await handle.result;
      // A terminal outcome can be constructed while its lease is being
      // released, or validation/checkpointing can fail after a stop request.
      // Join/reacquire cleanup only after that worker finishes. Structural
      // failures and immutable completed candidates must never be overridden.
      const protectedFailures = {
        DownloadFailureCode.busy,
        DownloadFailureCode.invalidSpec,
        DownloadFailureCode.unsafePath,
        DownloadFailureCode.candidateExists,
      };
      if (result.state != DownloadState.downloaded &&
          result.state != handle._stop &&
          !protectedFailures.contains(result.failure?.code)) {
        if (!handle._running) _launch(handle);
        return await handle.result;
      }
      return result;
    } finally {
      handle._controls--;
    }
  }

  void _requireOwner(DownloadHandle<T> handle) {
    if (!identical(handle._owner, this)) {
      throw const DownloadFailure(
        DownloadFailureCode.invalidSpec,
        detail: 'foreignHandle',
      );
    }
  }

  void _launch(DownloadHandle<T> handle) {
    handle._running = true;
    handle._state = DownloadState.queued;
    handle._resumedFrom = 0;
    handle._restartReason = null;
    handle._httpStatus = null;
    handle._result = _execute(handle);
  }

  Future<DownloadResult<T>> _execute(DownloadHandle<T> handle) async {
    DownloadStaging? staging;
    try {
      _checkSpec(handle.spec);
      if (timeout <= Duration.zero) {
        throw const DownloadFailure(
          DownloadFailureCode.invalidSpec,
          detail: 'timeout',
        );
      }
      validator.checkSpec(handle.spec);
      staging = await DownloadStaging.acquire(
        appSupportDirectory,
        handle.spec.destinationKey,
      );
      try {
        final hadLeftovers = await staging.hasLeftovers;
        var checkpoint = await staging.checkpointFor(handle.spec);
        if (checkpoint?.complete == true) {
          throw const DownloadFailure(DownloadFailureCode.candidateExists);
        }
        if (handle._stop != null) return await _stopped(handle, staging);
        if (checkpoint == null ||
            checkpoint.etag == null ||
            checkpoint.bytes == 0) {
          if (hadLeftovers) {
            handle._restartReason = DownloadRestartReason.untrustedProvenance;
          }
          await staging.discard();
          checkpoint = null;
        }
        return await _transfer(handle, staging, checkpoint);
      } finally {
        await staging.release();
        staging = null;
      }
    } on DownloadFailure catch (failure) {
      return _failure(handle, failure);
    } on FileSystemException catch (error) {
      return _failure(
        handle,
        DownloadFailure(
          error.osError?.errorCode == 28 || error.osError?.errorCode == 122
              ? DownloadFailureCode.insufficientStorage
              : DownloadFailureCode.ioFailure,
          osErrorCode: error.osError?.errorCode,
        ),
      );
    } on IOException catch (error) {
      return _failure(
        handle,
        DownloadFailure(
          DownloadFailureCode.networkFailure,
          detail: error.runtimeType.toString(),
        ),
      );
    } on TimeoutException {
      return _failure(
        handle,
        const DownloadFailure(
          DownloadFailureCode.networkFailure,
          detail: 'timeout',
        ),
      );
    } finally {
      handle._client?.close(force: true);
      handle._client = null;
      handle._request = null;
      handle._running = false;
    }
  }

  Future<DownloadResult<T>> _transfer(
    DownloadHandle<T> handle,
    DownloadStaging staging,
    DownloadCheckpoint? checkpoint,
  ) async {
    final spec = handle.spec;
    var offset = checkpoint?.bytes ?? 0;
    var previousTotal = checkpoint?.total;
    var previousEtag = checkpoint?.etag;
    handle._resumedFrom = offset;
    for (var round = 0; round < 2; round++) {
      handle._httpStatus = null;
      handle._resumedFrom = offset;
      handle._bytes = offset;
      handle._total = spec.expectedSize ?? previousTotal;
      await _checkSpace(
        staging,
        ((spec.expectedSize ?? previousTotal ?? offset) - offset),
      );
      if (handle._stop != null) return _stopped(handle, staging);
      handle._state = DownloadState.downloading;
      final client = _clientFactory()..autoUncompress = false;
      handle._client = client;
      client.connectionTimeout = timeout;
      late HttpClientResponse response;
      try {
        final request = await client.getUrl(spec.url).timeout(timeout);
        handle._request = request;
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        if (offset > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
          request.headers.set(HttpHeaders.ifRangeHeader, previousEtag!);
        }
        response = await request.close().timeout(timeout);
      } catch (_) {
        if (handle._stop != null) return _stopped(handle, staging);
        rethrow;
      }
      final status = response.statusCode;
      handle._httpStatus = status;
      final etag = _header(response, HttpHeaders.etagHeader);
      final encoding = _header(response, HttpHeaders.contentEncodingHeader);
      if (encoding != null && encoding.toLowerCase() != 'identity') {
        throw DownloadFailure(
          DownloadFailureCode.protocolFailure,
          httpStatus: status,
          detail: 'contentEncoding',
        );
      }
      if (offset > 0 &&
          (status == 416 || (status == 206 && etag != previousEtag))) {
        handle._restartReason = status == 416
            ? DownloadRestartReason.rangeNotSatisfiable
            : DownloadRestartReason.validatorChanged;
        client.close(force: true);
        await staging.discard();
        offset = 0;
        previousTotal = null;
        previousEtag = null;
        continue;
      }
      int? total;
      int? responseEndExclusive;
      if (status == HttpStatus.partialContent) {
        if (offset == 0) {
          throw DownloadFailure(
            DownloadFailureCode.invalidRange,
            httpStatus: status,
          );
        }
        final range = _parseRange(
          _header(response, HttpHeaders.contentRangeHeader),
        );
        if (range.$1 != offset ||
            range.$2 < offset ||
            range.$2 >= range.$3 ||
            (response.contentLength >= 0 &&
                response.contentLength != range.$2 - offset + 1) ||
            (previousTotal != null && range.$3 != previousTotal)) {
          throw DownloadFailure(
            DownloadFailureCode.invalidRange,
            httpStatus: status,
          );
        }
        total = range.$3;
        responseEndExclusive = range.$2 + 1;
      } else if (status == HttpStatus.ok) {
        if (_header(response, HttpHeaders.contentRangeHeader) != null) {
          throw DownloadFailure(
            DownloadFailureCode.invalidRange,
            httpStatus: status,
          );
        }
        if (offset > 0) {
          handle._restartReason = DownloadRestartReason.rangeIgnored;
          offset = 0;
          handle._resumedFrom = 0;
        }
        total = response.contentLength >= 0 ? response.contentLength : null;
      } else {
        throw DownloadFailure(
          DownloadFailureCode.httpFailure,
          httpStatus: status,
        );
      }
      if ((total != null && total > spec.maxBytes) ||
          (total != null &&
              spec.expectedSize != null &&
              total != spec.expectedSize)) {
        throw DownloadFailure(
          DownloadFailureCode.sizeMismatch,
          httpStatus: status,
        );
      }
      handle._total = total ?? spec.expectedSize;
      await _checkSpace(staging, (handle._total ?? offset) - offset);
      if (handle._stop != null) return _stopped(handle, staging);
      // No durable old checkpoint may survive a truncation or append. A crash
      // during the stream restarts cleanly; graceful pause/failure checkpoints.
      await staging.invalidateCheckpoint();
      final writer = await staging.openPayload(append: offset > 0);
      handle._bytes = offset;
      Object? streamError;
      StackTrace? streamStack;
      try {
        await for (final chunk in response.timeout(timeout)) {
          if (handle._stop != null) break;
          if (responseEndExclusive != null &&
              handle._bytes + chunk.length > responseEndExclusive) {
            throw const DownloadFailure(
              DownloadFailureCode.invalidRange,
              detail: 'rangeBodyTooLong',
            );
          }
          if (handle._bytes + chunk.length > spec.maxBytes ||
              (handle._total != null &&
                  handle._bytes + chunk.length > handle._total!)) {
            throw const DownloadFailure(DownloadFailureCode.sizeMismatch);
          }
          await _checkSpace(staging, chunk.length);
          await writer.writeFrom(chunk);
          handle._bytes += chunk.length;
        }
      } catch (error, stack) {
        streamError = error;
        streamStack = stack;
      } finally {
        try {
          await writer.flush();
        } finally {
          await writer.close();
        }
      }
      if (handle._stop != null) {
        if (handle._stop == DownloadState.paused) {
          await staging.saveCheckpoint(spec, etag: etag, total: handle._total);
        }
        return _stopped(handle, staging);
      }
      if (streamError != null) {
        // A disk fault has no trustworthy checkpoint; network interruptions do.
        if (streamError is IOException && streamError is! FileSystemException ||
            streamError is TimeoutException) {
          await staging.saveCheckpoint(spec, etag: etag, total: handle._total);
        }
        Error.throwWithStackTrace(streamError, streamStack!);
      }
      if (handle._total != null && handle._bytes != handle._total) {
        await staging.saveCheckpoint(spec, etag: etag, total: handle._total);
        throw const DownloadFailure(
          DownloadFailureCode.networkFailure,
          detail: 'incompleteBody',
        );
      }
      handle._state = DownloadState.verifying;
      late T evidence;
      try {
        evidence = await validator.validate(staging.directory, spec);
      } on DownloadFailure {
        rethrow;
      } catch (error) {
        throw DownloadFailure(
          DownloadFailureCode.verificationFailure,
          detail: error.runtimeType.toString(),
        );
      }
      if (handle._stop != null) {
        if (handle._stop == DownloadState.paused) {
          await staging.saveCheckpoint(spec, etag: etag, total: handle._bytes);
        }
        return _stopped(handle, staging);
      }
      await staging.saveCheckpoint(
        spec,
        etag: etag,
        total: handle._bytes,
        complete: true,
      );
      // Pause/cancel may arrive during the asynchronous durable checkpoint.
      // Keep the lease until acknowledgement, and never hand off afterwards.
      if (handle._stop != null) {
        if (handle._stop == DownloadState.paused) {
          await staging.saveCheckpoint(spec, etag: etag, total: handle._bytes);
        }
        return _stopped(handle, staging);
      }
      handle._state = DownloadState.downloaded;
      return DownloadResult(
        state: handle._state,
        evidence: evidence,
        stagedFile: staging.payload,
        resumedFrom: handle._resumedFrom,
        restartReason: handle._restartReason,
      );
    }
    throw const DownloadFailure(
      DownloadFailureCode.invalidRange,
      detail: 'restartExhausted',
    );
  }

  Future<DownloadResult<T>> _stopped(
    DownloadHandle<T> handle,
    DownloadStaging staging,
  ) async {
    if (handle._stop == DownloadState.cancelled) await staging.discard();
    handle._state = handle._stop!;
    return DownloadResult(
      state: handle._state,
      resumedFrom: handle._resumedFrom,
      restartReason: handle._restartReason,
    );
  }

  Future<void> _checkSpace(DownloadStaging staging, int needed) async {
    late int available;
    try {
      available = await spaceProbe.availableBytes(staging.directory);
    } catch (_) {
      throw const DownloadFailure(DownloadFailureCode.storageUnavailable);
    }
    if (available < 0) {
      throw const DownloadFailure(DownloadFailureCode.storageUnavailable);
    }
    if (available < needed + DownloadStaging.metadataLimit * 2) {
      throw const DownloadFailure(DownloadFailureCode.insufficientStorage);
    }
  }

  DownloadResult<T> _failure(
    DownloadHandle<T> handle,
    DownloadFailure failure, {
    bool preserveState = false,
  }) {
    // A busy caller does not mutate an already-running handle's state.
    if (!preserveState) {
      handle._state = DownloadState.failed;
    }
    return DownloadResult(
      state: DownloadState.failed,
      resumedFrom: handle._resumedFrom,
      restartReason: handle._restartReason,
      failure: DownloadFailure(
        failure.code,
        hostname: handle.spec.url.host,
        httpStatus: failure.httpStatus ?? handle._httpStatus,
        detail: failure.detail,
        osErrorCode: failure.osErrorCode,
      ),
    );
  }

  static String? _header(HttpClientResponse response, String name) {
    final values = response.headers[name];
    if (values == null) return null;
    if (values.length != 1) {
      throw DownloadFailure(
        DownloadFailureCode.protocolFailure,
        httpStatus: response.statusCode,
        detail: 'ambiguousHeader',
      );
    }
    return values.single;
  }

  static (int, int, int) _parseRange(String? value) {
    final match = RegExp(
      r'^bytes ([0-9]+)-([0-9]+)/([0-9]+)$',
    ).firstMatch(value ?? '');
    final values = match == null
        ? <int?>[]
        : [for (var i = 1; i <= 3; i++) int.tryParse(match.group(i)!)];
    if (values.length != 3 || values.any((value) => value == null)) {
      throw const DownloadFailure(DownloadFailureCode.invalidRange);
    }
    return (values[0]!, values[1]!, values[2]!);
  }

  static void _checkSpec(DownloadSpec spec) {
    if (spec.url.scheme != 'https' ||
        spec.url.host.isEmpty ||
        spec.url.userInfo.isNotEmpty ||
        spec.url.hasFragment ||
        spec.url.toString().length > 8192 ||
        spec.resourceId.isEmpty ||
        spec.resourceId.length > 256 ||
        spec.artifactRevision.isEmpty ||
        spec.artifactRevision.length > 256 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(spec.destinationKey) ||
        spec.maxBytes <= 0 ||
        (spec.expectedSize != null &&
            (spec.expectedSize! < 0 || spec.expectedSize! > spec.maxBytes)) ||
        (spec.expectedSha256 != null &&
            !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(spec.expectedSha256!))) {
      throw const DownloadFailure(DownloadFailureCode.invalidSpec);
    }
  }
}
