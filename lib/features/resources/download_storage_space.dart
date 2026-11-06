import 'dart:io';

import 'package:flutter/services.dart';

import 'download_contracts.dart';

class AndroidDownloadSpaceProbe implements DownloadSpaceProbe {
  const AndroidDownloadSpaceProbe();
  @override
  Future<int> availableBytes(Directory directory) async {
    try {
      final available = await const MethodChannel(
        'siraj/download_storage',
      ).invokeMethod<int>('availableBytes', {'path': directory.absolute.path});
      if (available == null || available < 0) {
        throw const DownloadFailure(DownloadFailureCode.storageUnavailable);
      }
      return available;
    } on PlatformException {
      throw const DownloadFailure(DownloadFailureCode.storageUnavailable);
    } on MissingPluginException {
      throw const DownloadFailure(DownloadFailureCode.storageUnavailable);
    }
  }
}
