package com.haruka.mp3_player;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class MediaPlayerImpl extends MediaPlayer {
    @Nullable
    @SuppressLint("StaticFieldLeak")
    private static MediaPlayerImpl instance;
    public static final String UPDATE_NOTIFICATION_ACTION = "com.haruka.mp3_player.UPDATE_NOTIFICATION_ACTION";
    public static final String UPDATE_STATE_METHOD = "com.haruka.mp3_player.UPDATE_STATE";
    public static final String ON_COMPLETION_METHOD = "com.haruka.mp3_player.ON_COMPLETION";
    public static final String ON_ERROR_METHOD = "com.haruka.mp3_player.ON_ERROR";
    public static final String ON_INFO_METHOD = "com.haruka.mp3_player.ON_INFO";
    public static final String ON_PREPARED_METHOD = "com.haruka.mp3_player.ON_PREPARED";
    public static final String ON_SEEK_COMPLETE_METHOD = "com.haruka.mp3_player.ON_SEEK_COMPLETE";

    public static final String INDEX_KEY = "INDEX";
    public static final String CURRENT_POSITION_KEY = "CURRENT_POSITION";
    public static final String DURATION_KEY = "DURATION";
    public static final String IS_PLAYING_KEY = "IS_PLAYING";
    public static final String PLAYLIST_ID_KEY = "PLAYLIST_ID";
    public static final String REPEAT_KEY = "REPEAT";

    @Nullable
    public TrackMetadata currentTrack;

    @NonNull
    private final ArrayList<TrackMetadata> tracks = new ArrayList<>(0);
    @Nullable
    private Context context;
    private int playlistId = -1;
    private int index = -1;
    private boolean mayResume = false;
    @NonNull
    private final ScheduledExecutorService executor = Executors.newScheduledThreadPool(1);

    private MediaPlayerImpl() {
        super();

        setAudioStreamType(AudioManager.STREAM_MUSIC);
        setOnCompletionListener(
                (player) -> {
                    if (context != null) {
                        context.sendBroadcast(new Intent(ON_COMPLETION_METHOD));
                    }

                    while (true) {
                        try {
                            index++;
                            if (index == tracks.size()) {
                                index = 0;
                            }

                            play();
                            break;
                        } catch (IOException error) {
                            error.printStackTrace();
                        }
                    }
                }
        );
        // https://developer.android.com/reference/android/media/MediaPlayer.OnErrorListener
        setOnErrorListener(
                (player, what, extra) -> {
                    if (context != null) {
                        context.sendBroadcast(
                                new Intent(ON_ERROR_METHOD)
                                        .putExtra("what", what)
                                        .putExtra("extra", extra)
                        );
                    }

                    return true;
                }
        );
        setOnInfoListener(
                (player, what, extra) -> {
                    if (context != null) {
                        context.sendBroadcast(
                                new Intent(ON_INFO_METHOD)
                                        .putExtra("what", what)
                                        .putExtra("extra", extra)
                        );
                    }

                    return true;
                }
        );
        setOnPreparedListener(
                (player) -> {
                    try {
                        start();
                    } catch (IllegalStateException error) {
                        error.printStackTrace();
                    }

                    if (context != null) {
                        context.sendBroadcast(new Intent(ON_PREPARED_METHOD));
                    }
                }
        );
        setOnSeekCompleteListener(
                (player) -> {
                    if (context != null) {
                        context.sendBroadcast(new Intent(ON_SEEK_COMPLETE_METHOD));
                    }
                }
        );

        executor.scheduleWithFixedDelay(this::sendState, 0, 300, TimeUnit.MILLISECONDS);
    }

    @NonNull
    public synchronized static MediaPlayerImpl create() {
        if (instance == null) instance = new MediaPlayerImpl();
        return instance;
    }

    @Nullable
    public synchronized Context getContext() {
        return context;
    }

    public synchronized void setContext(@Nullable Context context) {
        this.context = context;
    }

    public synchronized void setTracks(@NonNull List<TrackMetadata> updateTracks) {
        tracks.clear();
        tracks.addAll(updateTracks);
    }

    public void setTracks(@NonNull JSONArray updateTracks) throws JSONException {
        ArrayList<TrackMetadata> tracks = new ArrayList<>();
        for (int i = 0; i < updateTracks.length(); i++) {
            JSONObject data = updateTracks.getJSONObject(i);
            tracks.add(
                    new TrackMetadata(
                            data.getString("title"),
                            data.getString("artist"),
                            data.getString("uri"),
                            data.getString("thumbnailPath")
                    )
            );
        }

        setTracks(tracks);
    }

    public synchronized void setPlaylistId(int updatePlaylistId) {
        playlistId = updatePlaylistId;
    }

    public synchronized void setIndex(int updateIndex) {
        index = updateIndex;
    }

    private synchronized void sendState() {
        if (context != null) {
            Intent intent = new Intent(UPDATE_STATE_METHOD);
            intent.putExtra(INDEX_KEY, index);
            intent.putExtra(PLAYLIST_ID_KEY, playlistId);

            try {
                intent.putExtra(CURRENT_POSITION_KEY, getCurrentPosition());
            } catch (Throwable error) {
                intent.putExtra(CURRENT_POSITION_KEY, 0);
            }

            try {
                intent.putExtra(DURATION_KEY, getDuration());
            } catch (Throwable error) {
                intent.putExtra(DURATION_KEY, 0);
            }

            try {
                intent.putExtra(IS_PLAYING_KEY, isPlaying());
            } catch (Throwable error) {
                intent.putExtra(IS_PLAYING_KEY, false);
            }

            try {
                intent.putExtra(REPEAT_KEY, isLooping());
            } catch (Throwable error) {
                intent.putExtra(REPEAT_KEY, false);
            }

            context.sendBroadcast(intent);
        }
    }

    private synchronized void updateTrack(@Nullable TrackMetadata track) {
        currentTrack = track;
        if (context != null) {
            context.sendBroadcast(new Intent(UPDATE_NOTIFICATION_ACTION));
        }
    }

    public synchronized void play() throws IOException, IllegalStateException {
        reset();

        TrackMetadata track = tracks.get(index);
        String path = track.uri;
        setDataSource(path);
        updateTrack(track);

        prepareAsync();
    }

    @Override
    public synchronized void pause() throws IllegalStateException {
        if (isPlaying()) {
            super.pause();
            mayResume = true;
            sendState();
        }
    }

    public synchronized void resume() throws IllegalStateException {
        if (mayResume) {
            mayResume = false;
            start();
            sendState();
        }
    }

    @Override
    public synchronized void seekTo(int milliseconds) {
        super.seekTo(milliseconds);
        sendState();
    }

    public synchronized void next() throws IllegalStateException {
        super.stop();
        while (true) {
            try {
                index++;
                if (index == tracks.size()) {
                    index = 0;
                }

                play();
                return;
            } catch (IOException error) {
                error.printStackTrace();
            }
        }
    }

    public synchronized void previous() throws IllegalStateException {
        super.stop();
        while (true) {
            try {
                index--;
                if (index < 0) {
                    index = tracks.size() - 1;
                }

                play();
                return;
            } catch (IOException error) {
                error.printStackTrace();
            }
        }
    }

    @Override
    public synchronized void stop() throws IllegalStateException {
        super.stop();
        tracks.clear();
        playlistId = index = -1;
        mayResume = false;
        updateTrack(null);
        sendState();
    }

    public void toggleRepeat() {
        setLooping(!isLooping());
        sendState();
    }

    @Override
    public void release() {
        super.release();
        executor.shutdown();
    }
}
