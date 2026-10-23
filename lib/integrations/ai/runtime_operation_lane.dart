import 'dart:async';
import 'runtime_contract.dart';
import 'tutor_contract.dart';

/// One native operation at a time. Logical cancellation/timeout may finish
/// before native work; the lane remains occupied until work AND cancel drain.
class RuntimeOperationLane {
  RuntimeOperationLane(this.timeout) {
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout);
  }
  final Duration timeout;
  Future<void>? _idle;
  TutorCancellation? _active;
  String? _requestId;
  Future<void> get whenIdle => _idle ?? Future<void>.value();
  void requireIdle() {
    if (_idle != null) throw const RuntimeFailure(RuntimeErrorCode.busy);
  }

  void cancel(String requestId) {
    if (_requestId == requestId) _active?.cancel();
  }

  Future<T> run<T>({
    required TutorCancellation external,
    required Future<T> Function(TutorCancellation) work,
    String? requestId,
    Future<void> Function()? onCancel,
    void Function(T)? onSuccess,
    void Function(Object)? onFailure,
  }) async {
    requireIdle();
    if (external.isCancelled) {
      throw const RuntimeFailure(RuntimeErrorCode.cancelled);
    }
    final idle = Completer<void>();
    _idle = idle.future;
    final token = TutorCancellation();
    _active = token;
    _requestId = requestId;
    final logical = Completer<void>();
    final interrupted = Completer<T>();
    Future<void>? cancelDrain;
    var stopped = false;
    void interrupt(RuntimeErrorCode code) {
      if (stopped || logical.isCompleted) return;
      stopped = true;
      token.cancel();
      if (onCancel != null) {
        cancelDrain = Future<void>.sync(
          onCancel,
        ).then<void>((_) {}, onError: (Object _, StackTrace _) {});
      }
      interrupted.completeError(RuntimeFailure(code));
    }

    external.whenCancelled.then((_) => interrupt(RuntimeErrorCode.cancelled));
    token.whenCancelled.then((_) => interrupt(RuntimeErrorCode.cancelled));
    final timer = Timer(timeout, () => interrupt(RuntimeErrorCode.timeout));
    final actual = Future<T>.sync(() => work(token));
    var actualDone = false;
    final settled = actual.then<void>(
      (_) {
        actualDone = true;
      },
      onError: (Object _, StackTrace _) {
        actualDone = true;
      },
    );
    final drain = () async {
      await settled;
      await logical.future;
      if (cancelDrain != null) await cancelDrain;
      _active = null;
      _requestId = null;
      _idle = null;
      idle.complete();
    }();
    try {
      final value = await Future.any([actual, interrupted.future]);
      if (token.isCancelled) {
        throw const RuntimeFailure(RuntimeErrorCode.cancelled);
      }
      onSuccess?.call(value);
      return value;
    } catch (error) {
      onFailure?.call(error);
      rethrow;
    } finally {
      timer.cancel();
      logical.complete();
      if (actualDone && cancelDrain == null) await drain;
    }
  }
}
