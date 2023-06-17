package com.haruka.mp3_player;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONException;
import org.json.JSONObject;

public class TrackMetadata {
    @NonNull
    public final String title;
    @Nullable
    public final String artist;
    @NonNull
    public final String uri;
    @Nullable
    public final String thumbnailPath;

    public TrackMetadata(@NonNull String title, @Nullable String artist, @NonNull String uri, @Nullable String thumbnailPath) {
        this.title = title;
        this.artist = artist;
        this.uri = uri;
        this.thumbnailPath = thumbnailPath;
    }

    @NonNull
    public static TrackMetadata fromJson(@NonNull JSONObject data) throws JSONException {
        return new TrackMetadata(
                data.getString("title"),
                data.isNull("artist") ? null : data.getString("artist"),
                data.getString("uri"),
                data.isNull("thumbnailPath") ? null : data.getString("thumbnailPath")
        );
    }
}
