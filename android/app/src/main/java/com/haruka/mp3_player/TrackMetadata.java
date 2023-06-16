package com.haruka.mp3_player;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class TrackMetadata {
    @NonNull
    public final String title;
    @Nullable
    public final String artist;
    @NonNull
    public final String uri;
    @NonNull
    public final String thumbnailPath;

    TrackMetadata(@NonNull String title, @Nullable String artist, @NonNull String uri, @NonNull String thumbnailPath) {
        this.title = title;
        this.artist = artist;
        this.uri = uri;
        this.thumbnailPath = thumbnailPath;
    }
}
