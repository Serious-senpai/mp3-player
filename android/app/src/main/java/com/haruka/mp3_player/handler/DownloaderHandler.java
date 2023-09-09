package com.haruka.mp3_player.handler;

import androidx.annotation.NonNull;

import com.haruka.mp3_player.DownloadManager;

import java.net.URL;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class DownloaderHandler extends AbstractMethodChannelPlugin {
    public DownloaderHandler(@NonNull FlutterActivity flutterActivity) {
        super(flutterActivity, "com.haruka.mp3_player/downloader");
    }

    @Override
    protected void handler(@NonNull MethodCall method, @NonNull MethodChannel.Result result, @NonNull FlutterPluginBinding binding) throws Exception {
        if (method.method.equals("download")) {
            String url = method.argument("url");

            String outputFilePath = method.argument("outputFilePath");
            assert outputFilePath != null;

            String iconUrl = method.argument("iconUrl");
            assert iconUrl != null;

            String description = method.argument("description");
            assert description != null;

            DownloadManager manager = new DownloadManager(
                    new URL(url),
                    outputFilePath,
                    new URL(iconUrl),
                    description,
                    binding.getApplicationContext()
            );
            manager.task.run();

            result.success(null);
        } else {
            result.notImplemented();
        }
    }

    @Override
    protected void whenAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }
}
