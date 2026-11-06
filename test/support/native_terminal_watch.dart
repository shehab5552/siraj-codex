/// Test-only observer: install before requesting generation because the native
/// terminal event may precede its MethodChannel acknowledgement.
Future<Map<Object?, Object?>> observeNativeTerminal(
  Stream<Object?> events,
  String requestId,
) async =>
    (await events.firstWhere(
          (event) =>
              event is Map &&
              event['requestId'] == requestId &&
              const [
                'generationCancelled',
                'generationFailed',
                'generationCompleted',
              ].contains(event['type']),
        ))
        as Map<Object?, Object?>;
