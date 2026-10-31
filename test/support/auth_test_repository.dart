import 'dart:async';
import 'dart:typed_data';
import 'package:drift/drift.dart' show QueryRow;
import 'package:siraj/data/user_repository.dart';

class PausedNoncePublish extends UserRepository {
  PausedNoncePublish(super.db);
  bool pause = false;
  final committed = Completer<void>();
  final release = Completer<void>();
  bool failNextRead = false;
  @override
  Future<QueryRow?> currentAccount() {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('isolated validation read failure');
    }
    return super.currentAccount();
  }

  @override
  Future<int> compareAndSetNonceHash({
    required String userId,
    required String accountEpoch,
    required Uint8List? expectedNonceHash,
    required Uint8List hash,
    required String nowUtc,
    bool Function()? isRequestCurrent,
  }) async {
    final result = await super.compareAndSetNonceHash(
      userId: userId,
      accountEpoch: accountEpoch,
      expectedNonceHash: expectedNonceHash,
      hash: hash,
      nowUtc: nowUtc,
      isRequestCurrent: isRequestCurrent,
    );
    if (pause) {
      committed.complete();
      await release.future;
    }
    return result;
  }
}
