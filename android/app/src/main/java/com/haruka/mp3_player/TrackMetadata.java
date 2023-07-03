package com.haruka.mp3_player;

import android.media.MediaMetadata;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * The minimal audio metadata sent from Dart to display on the notification and send to {@link MediaPlayerImpl}.
 */
public class TrackMetadata {
    /**
     * The track title.
     */
    @NonNull
    public final String title;
    /**
     * The track artist, may be null.
     */
    @Nullable
    public final String artist;
    /**
     * The track URI (i.e. path to audio file).
     */
    @NonNull
    public final String uri;
    /**
     * Path to the track's thumbnail, may be null.
     */
    @Nullable
    public final String thumbnailPath;

    /**
     * Initialize a {@link TrackMetadata} from the given data.
     *
     * @param title         The track title
     * @param artist        The track artist
     * @param uri           The track URI
     * @param thumbnailPath The track thumbnail URI
     */
    public TrackMetadata(@NonNull String title, @Nullable String artist, @NonNull String uri, @Nullable String thumbnailPath) {
        this.title = title;
        this.artist = artist;
        this.uri = uri;
        this.thumbnailPath = thumbnailPath;
    }

    /**
     * Construct a {@link TrackMetadata} by parsing the {@link JSONObject} given from Dart.
     *
     * @param data The {@link JSONObject} sent from Dart.
     * @return The created track.
     * @throws JSONException The parsing process somehow failed.
     */
    @NonNull
    public static TrackMetadata fromJson(@NonNull JSONObject data) throws JSONException {
        return new TrackMetadata(
                data.getString("title"),
                data.isNull("artist") ? null : data.getString("artist"),
                data.getString("uri"),
                data.isNull("thumbnailPath") ? null : data.getString("thumbnailPath")
        );
    }

    @NonNull
    public MediaMetadata toMediaMetadata(){
        return new MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
                .build();
    }
}
