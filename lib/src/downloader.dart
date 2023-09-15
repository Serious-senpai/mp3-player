import "package:async_locks/async_locks.dart";
import "package:flutter/services.dart";

import "utils.dart";

const _platform = MethodChannel("com.haruka.mp3_player/downloader", JSONMethodCodec());
final _lock = Lock();

Future<void> download({
  required String url,
  required String outputFilePath,
  required String iconUrl,
  required String description,
}) async {
  try {
    await _lock.run(
      () async {
        await showToast("Downloading $description");
        await _platform.invokeMethod(
          "download",
          {
            "url": url,
            "outputFilePath": outputFilePath,
            "iconUrl": iconUrl,
            "description": description,
          },
        );
      },
    );
  } on Object catch (error, stackTrace) {
    print(error);
    print(stackTrace);
  }
}
