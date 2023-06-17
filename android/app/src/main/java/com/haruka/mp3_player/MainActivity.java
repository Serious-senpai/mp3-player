package com.haruka.mp3_player;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.PluginRegistry;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        MediaMetadataHandler mediaMetadataHandler = new MediaMetadataHandler(this);
        MediaPlayerHandler mediaPlayerHandler = new MediaPlayerHandler(this);
        UtilsHandler utilsHandler = new UtilsHandler(this);

        PluginRegistry pluginRegistry = flutterEngine.getPlugins();
        pluginRegistry.add(mediaMetadataHandler);
        pluginRegistry.add(mediaPlayerHandler);
        pluginRegistry.add(utilsHandler);
    }
}
