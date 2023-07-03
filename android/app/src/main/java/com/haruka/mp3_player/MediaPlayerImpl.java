package com.haruka.mp3_player;

import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.session.MediaSession;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Controller for a {@link MediaPlayer} that manages playbacks and broadcasting state.
 */
public class MediaPlayerImpl extends MediaPlayer {
    @Nullable
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
    public static final String SHUFFLE_KEY = "SHUFFLE";

    private static final String MEDIA_SESSION_TAG = "mp3_player.MediaSession";

    /**
     * The current playing track, if any.
     */
    @Nullable
    public TrackMetadata currentTrack;

    @NonNull
    private final ArrayList<TrackMetadata> tracks = new ArrayList<>(0);
    @Nullable
    public MediaSession mediaSession;
    @NonNull
    private final Random rng = new Random();
    private int playlistId = -1;
    private int index = -1;
    private boolean mayResume = false;
    private boolean shuffle = false;
    @NonNull
    private final ScheduledExecutorService executor = Executors.newScheduledThreadPool(1);

    private MediaPlayerImpl(@Nullable Context context) {
        super();

        if (context != null) {
            mediaSession = new MediaSession(context, MEDIA_SESSION_TAG);
            mediaSession.setActive(true);
        }

        setAudioStreamType(AudioManager.STREAM_MUSIC);
        setOnCompletionListener(
                (player) -> {
                    if (context != null) {
                        context.sendBroadcast(new Intent(ON_COMPLETION_METHOD));
                    }

                    while (true) {
                        try {
                            if (shuffle) {
                                index = rng.nextInt(tracks.size());
                            } else {
                                index++;
                                if (index == tracks.size()) {
                                    index = 0;
                                }
                            }

                            play(context);
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
                        context.sendBroadcast(new Intent(UPDATE_NOTIFICATION_ACTION));
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

        executor.scheduleWithFixedDelay(() -> sendState(context), 0, 300, TimeUnit.MILLISECONDS);
    }

    /**
     * Get the singleton instance of {@link MediaPlayerImpl}, generate one if necessary.
     *
     * @param context The application context to send state via broadcast.
     * @return The singleton instance of {@link MediaPlayerImpl}
     */
    @NonNull
    public synchronized static MediaPlayerImpl create(@Nullable Context context) {
        if (instance == null) instance = new MediaPlayerImpl(context);
        return instance;
    }

    /**
     * Set the tracks to be played.
     *
     * @param updateTracks Tracks to be played.
     */
    public synchronized void setTracks(@NonNull List<TrackMetadata> updateTracks) {
        tracks.clear();
        tracks.addAll(updateTracks);
    }

    /**
     * Set the tracks to be played by parsing a {@link JSONArray}.
     *
     * @param updateTracks Tracks to be played.
     * @throws JSONException Exceptions when parsing {@link JSONArray}.
     */
    public void setTracks(@NonNull JSONArray updateTracks) throws JSONException {
        ArrayList<TrackMetadata> tracks = new ArrayList<>();
        for (int i = 0; i < updateTracks.length(); i++) {
            JSONObject data = updateTracks.getJSONObject(i);
            tracks.add(TrackMetadata.fromJson(data));
        }

        setTracks(tracks);
    }

    /**
     * Set the current playlist ID. This value is only used by the Dart side when recovering state.
     *
     * @param updatePlaylistId The playlist ID.
     */
    public synchronized void setPlaylistId(int updatePlaylistId) {
        playlistId = updatePlaylistId;
    }

    /**
     * Set the index (starting from 0) of the playing track among the given tracks.
     *
     * @param updateIndex The track index.
     */
    public synchronized void setIndex(int updateIndex) {
        index = updateIndex;
    }

    private synchronized void sendState(@Nullable Context context) {
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

            intent.putExtra(SHUFFLE_KEY, shuffle);

            context.sendBroadcast(intent);
        }
    }

    private synchronized void updateTrack(@Nullable TrackMetadata track, @Nullable Context context) {
        currentTrack = track;
        if (context != null) {
            context.sendBroadcast(new Intent(UPDATE_NOTIFICATION_ACTION));
        }
    }

    /**
     * Start playing at the given index of the given playlist.
     *
     * @param context The application context to send state via broadcast.
     * @throws IOException           Exception when reading data source.
     * @throws IllegalStateException This should never happens.
     */
    public synchronized void play(@Nullable Context context) throws IOException, IllegalStateException {
        reset();

        TrackMetadata track = tracks.get(index);
        String path = track.uri;
        setDataSource(path);
        updateTrack(track, context);

        if (mediaSession == null) {
            mediaSession = new MediaSession(context, MEDIA_SESSION_TAG);
            mediaSession.setActive(true);
        }

        mediaSession.setMetadata(track.toMediaMetadata());

        prepareAsync();
    }

    /**
     * @throws IllegalStateException The player is in an invalid state.
     * @deprecated Use {@link #pause(Context)} instead
     */
    @Override
    @Deprecated
    public synchronized void pause() throws IllegalStateException {
        pause(null);
    }

    /**
     * Pause the playing audio.
     *
     * @param context The application context to send state via broadcast.
     * @throws IllegalStateException The player is in an invalid state.
     */
    public synchronized void pause(@Nullable Context context) throws IllegalStateException {
        if (isPlaying()) {
            super.pause();
            mayResume = true;
            sendState(context);

            if (context != null) {
                context.sendBroadcast(new Intent(UPDATE_NOTIFICATION_ACTION));
            }
        }
    }

    /**
     * Resume the playing audio.
     *
     * @param context The application context to send state via broadcast.
     * @throws IllegalStateException The player is in an invalid state.
     */
    public synchronized void resume(@Nullable Context context) throws IllegalStateException {
        if (mayResume) {
            mayResume = false;
            start();
            sendState(context);

            if (context != null) {
                context.sendBroadcast(new Intent(UPDATE_NOTIFICATION_ACTION));
            }
        }
    }

    /**
     * @param milliseconds the offset in milliseconds from the start to seek to
     * @throws IllegalStateException The player is in an invalid state.
     * @deprecated Use {@link #seekTo(int, Context)} instead.
     */
    @Override
    @Deprecated
    public synchronized void seekTo(int milliseconds) throws IllegalStateException {
        seekTo(milliseconds, null);
    }

    /**
     * Seek to the specified position.
     *
     * @param milliseconds The offset in milliseconds from the start to seek to.
     * @param context      The application context to send state via broadcast.
     * @throws IllegalStateException The player is in an invalid state.
     */
    public synchronized void seekTo(int milliseconds, @Nullable Context context) throws IllegalStateException {
        super.seekTo(milliseconds);
        sendState(context);
    }

    /**
     * Skip to the next track in the given playlist.
     *
     * @param context The application context to send state via broadcast.
     * @throws IllegalStateException The player is in an invalid state.
     */
    public synchronized void next(@Nullable Context context) throws IllegalStateException {
        super.stop();
        while (true) {
            try {
                if (shuffle) {
                    index = rng.nextInt(tracks.size());
                } else {
                    index++;
                    if (index == tracks.size()) {
                        index = 0;
                    }
                }

                play(context);
                return;
            } catch (IOException error) {
                error.printStackTrace();
            }
        }
    }

    /**
     * Skip to the previous track in the given playlist.
     *
     * @param context The application context to send state via broadcast.
     * @throws IllegalStateException The player is in an invalid state.
     */
    public synchronized void previous(@Nullable Context context) throws IllegalStateException {
        super.stop();
        while (true) {
            try {
                index--;
                if (index < 0) {
                    index = tracks.size() - 1;
                }

                play(context);
                return;
            } catch (IOException error) {
                error.printStackTrace();
            }
        }
    }

    /**
     * @throws IllegalStateException The player is in an invalid state.
     * @deprecated Use {@link #stop(Context)} instead.
     */
    @Override
    @Deprecated
    public synchronized void stop() throws IllegalStateException {
        stop(null);
    }

    /**
     * Stop the audio playback.
     *
     * @param context The application context to send state via broadcast.
     * @throws IllegalStateException The player is in an invalid state.
     */
    public synchronized void stop(@Nullable Context context) throws IllegalStateException {
        super.stop();
        tracks.clear();
        playlistId = index = -1;
        mayResume = false;
        updateTrack(null, context);
        sendState(context);
    }

    /**
     * Toggle the REPEAT mode.
     *
     * @param context The application context to send state via broadcast.
     */
    public void toggleRepeat(@Nullable Context context) {
        setLooping(!isLooping());
        sendState(context);
    }

    /**
     * Toggle the SHUFFLE mode.
     *
     * @param context The application context to send state via broadcast.
     */
    public void toggleShuffle(@Nullable Context context) {
        shuffle = !shuffle;
        sendState(context);
    }

    @Override
    public void release() {
        super.release();
        executor.shutdown();

        if (mediaSession != null) {
            mediaSession.setActive(false);
            mediaSession.release();
        }
    }
}
