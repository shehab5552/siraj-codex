import 'dart:async';
import 'package:siraj/features/auth/auth_models.dart';
import 'package:siraj/features/auth/session_marker_store.dart';

class ControlledMarker implements SessionMarkerStore {
  String? raw;
  bool pauseNext = false;
  bool failAfterWrite = false;
  bool failBeforeWrite = false;
  bool failClear = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(PersistedSessionMarker marker) async {
    if (pauseNext) {
      pauseNext = false;
      entered.complete();
      await release.future;
    }
    if (failBeforeWrite) throw StateError('isolated write failure');
    raw = marker.encode();
    if (failAfterWrite) {
      throw StateError('isolated lost storage acknowledgement');
    }
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('isolated clear failure');
    raw = null;
  }
}
