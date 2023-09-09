import "package:flutter/services.dart";

const _platform = MethodChannel("com.haruka.mp3_player/downloader", JSONMethodCodec());

Future<void> startDownload({
  required String url,
  required String outputFilePath,
  required String iconUrl,
  required String description,
}) async {
  await _platform.invokeMethod(
    "download",
    {
      "url": url,
      "outputFilePath": outputFilePath,
      "iconUrl": iconUrl,
      "description": description,
    },
  );
}
