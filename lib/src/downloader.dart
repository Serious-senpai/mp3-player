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
  print("Waiting to download $description: $url");
  try {
    await _lock.run(
      () => _platform.invokeMethod(
        "download",
        {
          "url": url,
          "outputFilePath": outputFilePath,
          "iconUrl": iconUrl,
          "description": description,
        },
      ),
    );
    print("Downloaded $description: $url");
  } on Object {
    await showToast("Download failed");
  }
}
