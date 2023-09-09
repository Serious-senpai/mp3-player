package com.haruka.mp3_player.handler;

import java.io.File;
import java.io.FileOutputStream;
import java.util.HashMap;

import android.media.MediaMetadataRetriever;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static android.media.MediaMetadataRetriever.*;

import com.haruka.mp3_player.Utility;

/**
 * A {@link FlutterPlugin} that handles requests related to audio metadata.
 */
public class MediaMetadataHandler extends AbstractMethodChannelPlugin {
    private int thumbnailCounter = 0;
    private static final MediaMetadataRetriever mediaMetadataRetriever = new MediaMetadataRetriever();

    /**
     * Construct a new {@link MediaMetadataHandler} instance.
     *
     * @param flutterActivity The {@link FlutterActivity} that registers this plugin.
     */
    public MediaMetadataHandler(@NonNull FlutterActivity flutterActivity) {
        super(flutterActivity, "com.haruka.mp3_player/media_metadata");
        removeFileEntity(flutterActivity.getCacheDir(), false);
    }

    @Override
    protected void handler(@NonNull MethodCall method, @NonNull MethodChannel.Result result, @NonNull FlutterPluginBinding binding) throws Exception {
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
                byte[] artwork = mediaMetadataRetriever.getEmbeddedPicture(); // May spit out errors when returns null, ignore it.
                if (artwork == null) {
                    result.success(null);
                } else {
                    File outputFile = new File(flutterActivity.getCacheDir().getAbsolutePath(), Utility.format("thumbnail_%d.png", thumbnailCounter++));
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

    @Override
    protected void whenAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
    }

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
