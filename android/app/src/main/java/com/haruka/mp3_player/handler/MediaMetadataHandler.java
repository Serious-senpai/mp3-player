package com.haruka.mp3_player.handler;

import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;
import java.util.Locale;

import android.media.MediaMetadataRetriever;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.JSONMethodCodec;
import io.flutter.plugin.common.MethodChannel;

import static android.media.MediaMetadataRetriever.*;

public class MediaMetadataHandler implements FlutterPlugin {
    private int thumbnailCounter = 0;
    private final MediaMetadataRetriever mediaMetadataRetriever = new MediaMetadataRetriever();
    private final FlutterActivity activity;

    public MediaMetadataHandler(@NonNull FlutterActivity flutterActivity) {
        activity = flutterActivity;
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        File cacheDir = activity.getCacheDir();
        removeFileEntity(cacheDir, false);

        new MethodChannel(binding.getBinaryMessenger(), "com.haruka.mp3_player/media_metadata", JSONMethodCodec.INSTANCE)
                .setMethodCallHandler(
                        new MethodHandlerWrapper(
                                (method, result) -> {
                                    mediaMetadataRetriever.setDataSource(method.<String>argument("path"));
                                    switch (method.method) {
                                        case "extractMetadata":
                                            HashMap<String, String> metadata = new HashMap<>();
                                            metadata.put("album", mediaMetadataRetriever.extractMetadata(METADATA_KEY_ALBUM));
                                            metadata.put("album_artist", mediaMetadataRetriever.extractMetadata(METADATA_KEY_ALBUMARTIST));
                                            metadata.put("artist", mediaMetadataRetriever.extractMetadata(METADATA_KEY_ARTIST));
                                            metadata.put("author", mediaMetadataRetriever.extractMetadata(METADATA_KEY_AUTHOR));
                                            metadata.put("compilation", mediaMetadataRetriever.extractMetadata(METADATA_KEY_COMPILATION));
                                            metadata.put("composer", mediaMetadataRetriever.extractMetadata(METADATA_KEY_COMPOSER));
                                            metadata.put("date", mediaMetadataRetriever.extractMetadata(METADATA_KEY_DATE));
                                            metadata.put("duration", mediaMetadataRetriever.extractMetadata(METADATA_KEY_DURATION));
                                            metadata.put("genre", mediaMetadataRetriever.extractMetadata(METADATA_KEY_GENRE));
                                            metadata.put("mimetype", mediaMetadataRetriever.extractMetadata(METADATA_KEY_MIMETYPE));
                                            metadata.put("title", mediaMetadataRetriever.extractMetadata(METADATA_KEY_TITLE));
                                            metadata.put("year", mediaMetadataRetriever.extractMetadata(METADATA_KEY_YEAR));

                                            result.success(metadata);
                                            break;

                                        case "getEmbeddedPicture":
                                            byte[] artwork = mediaMetadataRetriever.getEmbeddedPicture(); // Prints "getEmbeddedPicture: Call to getEmbeddedPicture failed." when returns null, ignore it.
                                            if (artwork == null) {
                                                result.success(null);
                                            } else {
                                                File outputFile = new File(cacheDir.getAbsolutePath(), String.format(Locale.US, "thumbnail_%d.png", thumbnailCounter++));
                                                assert outputFile.createNewFile();
                                                try (FileOutputStream stream = new FileOutputStream(outputFile)) {
                                                    stream.write(artwork);
                                                }

                                                HashMap<String, String> artworkData = new HashMap<>();
                                                artworkData.put("path", outputFile.getAbsolutePath());
                                                result.success(artworkData);
                                            }
                                            break;

                                        default:
                                            result.notImplemented();
                                    }
                                }
                        )
                );
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {}

    private void removeFileEntity(@NonNull File entity, boolean deleteSelf) {
        if (entity.isDirectory()) {
            File[] content = entity.listFiles();
            for (File f : content != null ? content : new File[]{}) {
                removeFileEntity(f, true);
            }
        }

        if (deleteSelf) {
            boolean result = entity.delete();
            assert result;
        }
    }
}
