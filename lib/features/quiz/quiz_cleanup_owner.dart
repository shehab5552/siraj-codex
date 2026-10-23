/// App-scoped owner of resource cleanup, independent of a disposed quiz view.
/// Failed actions retain only resource IDs/port, never questions or answers.
class QuizCleanupOwner {
  final _pending = <Future<void>>{};
  final _failed = <Future<void> Function()>{};
  Future<void>? _retrying;
  bool get needsRetry => _failed.isNotEmpty;
  bool get busy => _pending.isNotEmpty || _retrying != null;

  Future<void> track(Future<void> Function() action) {
    late final Future<void> job;
    job = Future<void>.sync(action)
        .then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {
            _failed.add(action);
          },
        )
        .whenComplete(() => _pending.remove(job));
    _pending.add(job);
    return job;
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_pending));
    }
  }

  /// Explicit bounded retry; repeated calls coalesce. No infinite backoff loop.
  Future<void> retry() =>
      _retrying ??= _retry().whenComplete(() => _retrying = null);
  Future<void> _retry() async {
    await drain();
    final actions = List<Future<void> Function()>.of(_failed);
    _failed.clear();
    for (final action in actions) {
      track(action);
    }
    await drain();
  }
}
