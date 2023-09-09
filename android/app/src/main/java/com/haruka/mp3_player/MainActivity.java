package com.haruka.mp3_player;

import androidx.annotation.NonNull;

import com.haruka.mp3_player.handler.DownloaderHandler;
import com.haruka.mp3_player.handler.MediaMetadataHandler;
import com.haruka.mp3_player.handler.MediaPlayerHandler;
import com.haruka.mp3_player.handler.UtilsHandler;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.PluginRegistry;

/**
 * The main {@link FlutterActivity} of the application
 */
public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        DownloaderHandler downloaderHandler = new DownloaderHandler(this);
        MediaMetadataHandler mediaMetadataHandler = new MediaMetadataHandler(this);
        MediaPlayerHandler mediaPlayerHandler = new MediaPlayerHandler(this);
        UtilsHandler utilsHandler = new UtilsHandler(this);

        PluginRegistry pluginRegistry = flutterEngine.getPlugins();
        pluginRegistry.add(downloaderHandler);
        pluginRegistry.add(mediaMetadataHandler);
        pluginRegistry.add(mediaPlayerHandler);
        pluginRegistry.add(utilsHandler);
    }
}
