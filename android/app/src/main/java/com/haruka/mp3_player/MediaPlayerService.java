package com.haruka.mp3_player;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.R.drawable;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.session.MediaSession;
import androidx.media3.session.MediaStyleNotificationHelper;

import com.haruka.mp3_player.handler.MediaPlayerHandler.PlayerStateReceiver;

import java.util.ArrayList;

import io.flutter.embedding.android.FlutterActivity;

public class MediaPlayerService extends Service {
    private static final int NOTIFICATION_ID = 1;
    private static final String NOTIFICATION_CHANNEL_ID = "com.haruka.mp3_player.MediaPlayerNotificationChannel";
    private static final String NOTIFICATION_CHANNEL_NAME = "MediaPlayerNotificationChannel";

    public class MediaControlReceiver extends BroadcastReceiver {
        public static final String NEXT_ACTION = "com.haruka.mp3_player.NEXT";
        public static final String PAUSE_ACTION = "com.haruka.mp3_player.PAUSE";
        public static final String PLAY_ACTION = "com.haruka.mp3_player.PLAY";
        public static final String PREVIOUS_ACTION = "com.haruka.mp3_player.PREVIOUS";
        public static final String RESUME_ACTION = "com.haruka.mp3_player.RESUME";
        public static final String SEEK_ACTION = "com.haruka.mp3_player.SEEK";
        public static final String STOP_ACTION = "com.haruka.mp3_player.STOP";
        public static final String SWITCH_REPEAT_ACTION = "com.haruka.mp3_player.SWITCH_REPEAT_ACTION";
        public static final String SWITCH_SHUFFLE_ACTION = "com.haruka.mp3_player.SWITCH_SHUFFLE_ACTION";

        public static final String PLAYLIST_ID_KEY = "PLAYLIST_ID_KEY";
        public static final String INITIAL_INDEX_KEY = "INITIAL_INDEX_KEY";
        public static final String PLAYLIST_BUNDLE_KEY = "PLAYLIST_BUNDLE_KEY";
        public static final String PLAYLIST_BUNDLE_LIST_KEY = "PLAYLIST_BUNDLE_LIST_KEY";
        public static final String POSITION_MS_KEY = "POSITION_MS_KEY";

        @Override
        public void onReceive(Context context, Intent intent) {
            Player player = getMediaSession().getPlayer();
            switch (intent.getAction()) {
                case NEXT_ACTION:
                    player.seekToNextMediaItem();
                    break;

                case PAUSE_ACTION:
                    player.pause();
                    break;

                case PLAY_ACTION:
                    playlistId = intent.getIntExtra(PLAYLIST_ID_KEY, -1);
                    int index = intent.getIntExtra(INITIAL_INDEX_KEY, 0);

                    Bundle bundle = intent.getBundleExtra(PLAYLIST_BUNDLE_KEY);
                    ArrayList<Bundle> playlistBundle;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        playlistBundle = bundle.getParcelableArrayList(PLAYLIST_BUNDLE_LIST_KEY, Bundle.class);
                    } else {
                        playlistBundle = bundle.getParcelableArrayList(PLAYLIST_BUNDLE_LIST_KEY);
                    }

                    ArrayList<MediaItem> playlist = new ArrayList<>();
                    for (Bundle item : playlistBundle) {
                        MediaItem mediaItem = MediaItem.CREATOR.fromBundle(item);
                        mediaItem = mediaItem.buildUpon()
                                .setUri(mediaItem.requestMetadata.mediaUri)
                                .build();

                        playlist.add(mediaItem);
                    }

                    player.setMediaItems(playlist);
                    player.prepare();
                    player.seekTo(index, 0);
                    player.play();
                    break;

                case PREVIOUS_ACTION:
                    player.seekToPreviousMediaItem();
                    break;

                case RESUME_ACTION:
                    player.play();
                    break;

                case SEEK_ACTION:
                    long position = intent.getIntExtra(POSITION_MS_KEY, 0);
                    player.seekTo(position);
                    break;

                case STOP_ACTION:
                    stopSelf();
                    break;

                case SWITCH_REPEAT_ACTION:
                    player.setRepeatMode((player.getRepeatMode() + 1) % 3);
                    break;

                case SWITCH_SHUFFLE_ACTION:
                    player.setShuffleModeEnabled(!player.getShuffleModeEnabled());
                    break;

                default:
                    throw new UnsupportedOperationException(Utility.format("Unsupported action %s", intent.getAction()));
            }
        }
    }

    private int playlistId = -1;
    private boolean shouldSendState = false;

    @NonNull
    private final MediaControlReceiver receiver = new MediaControlReceiver();

    @Nullable
    private ExoPlayer player;

    @Nullable
    private MediaSession mediaSession;

    @NonNull
    private synchronized MediaSession getMediaSession() {
        if (mediaSession == null) {
            if (player == null) {
                player = new ExoPlayer.Builder(getApplicationContext())
                        .setAudioAttributes(
                                new AudioAttributes.Builder()
                                        .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                                        .setUsage(C.USAGE_MEDIA)
                                        .build(),
                                true
                        )
                        .setPauseAtEndOfMediaItems(false)
                        .setHandleAudioBecomingNoisy(true)
                        .build();
            }

            mediaSession = new MediaSession.Builder(getApplicationContext(), player)
                    .setSessionActivity(getPlayingScreenPendingIntent())
                    .build();
        }

        return mediaSession;
    }

    @Nullable
    private NotificationCompat.Builder notificationBuilder;

    @NonNull
    private NotificationCompat.Builder getNotificationBuilder() {
        if (notificationBuilder == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                createNotificationChannel();
            }

            notificationBuilder = new NotificationCompat.Builder(getApplicationContext(), NOTIFICATION_CHANNEL_ID);
        }

        return notificationBuilder;
    }

    @NonNull
    private PendingIntent getPlayingScreenPendingIntent() {
        return PendingIntent.getActivity(
                getApplicationContext(), 1,
                new FlutterActivity.NewEngineIntentBuilder(MainActivity.class)
                        .initialRoute("/playing")
                        .build(getApplicationContext()),
                PendingIntent.FLAG_IMMUTABLE
        );
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(MediaControlReceiver.NEXT_ACTION);
        intentFilter.addAction(MediaControlReceiver.PAUSE_ACTION);
        intentFilter.addAction(MediaControlReceiver.PLAY_ACTION);
        intentFilter.addAction(MediaControlReceiver.PREVIOUS_ACTION);
        intentFilter.addAction(MediaControlReceiver.RESUME_ACTION);
        intentFilter.addAction(MediaControlReceiver.SEEK_ACTION);
        intentFilter.addAction(MediaControlReceiver.STOP_ACTION);
        intentFilter.addAction(MediaControlReceiver.SWITCH_REPEAT_ACTION);
        intentFilter.addAction(MediaControlReceiver.SWITCH_SHUFFLE_ACTION);
        registerReceiver(receiver, intentFilter);
        receiver.onReceive(getApplicationContext(), intent);

        Handler handler = new Handler(Looper.myLooper());
        Runnable sendStateRunner = new Runnable() {
            @Override
            public void run() {
                sendState();
                handler.postDelayed(this, 300);
            }
        };
        handler.postDelayed(sendStateRunner, 0);

        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        unregisterReceiver(receiver);
        playlistId = -1;
        sendState();

        // Only release resources at the end
        if (player != null) player.release();
        if (mediaSession != null) mediaSession.release();
    }

    private synchronized void sendState() {
        Context context = getApplicationContext();
        Player player = getMediaSession().getPlayer();
        if (playlistId != -1) shouldSendState = true;
        if (shouldSendState) {
            Intent intent = new Intent(PlayerStateReceiver.UPDATE_STATE_ACTION);
            intent.putExtra(PlayerStateReceiver.INDEX_KEY, player.getCurrentMediaItemIndex());
            intent.putExtra(PlayerStateReceiver.PLAYLIST_ID_KEY, playlistId);
            intent.putExtra(PlayerStateReceiver.CURRENT_POSITION_KEY, player.getCurrentPosition());
            intent.putExtra(PlayerStateReceiver.DURATION_KEY, player.getDuration());
            intent.putExtra(PlayerStateReceiver.IS_PLAYING_KEY, player.isPlaying());
            intent.putExtra(PlayerStateReceiver.REPEAT_KEY, player.getRepeatMode());
            intent.putExtra(PlayerStateReceiver.SHUFFLE_KEY, player.getShuffleModeEnabled());

            context.sendBroadcast(intent);
            updateNotification();

            if (playlistId == -1) shouldSendState = false;
        }
    }

    @Nullable
    private Bitmap getThumbnail() {
        Player player = getMediaSession().getPlayer();
        try {
            assert player.getCurrentMediaItem() != null;
            assert player.getCurrentMediaItem().mediaMetadata.artworkUri != null;
            return BitmapFactory.decodeFile(player.getCurrentMediaItem().mediaMetadata.artworkUri.getPath());
        } catch (Throwable e) {
            try {
                return Utility.getApplicationIcon(getApplicationContext());
            } catch (PackageManager.NameNotFoundException ignored) {
            }
        }

        return null;
    }

    private void updateNotification() {
        Player player = getMediaSession().getPlayer();
        MediaSession mediaSession = getMediaSession();

        NotificationCompat.Builder builder = getNotificationBuilder();
        Bitmap thumbnail = getThumbnail();
        if (thumbnail != null) {
            builder.setColor(Utility.getDominantColor(thumbnail))
                    .setLargeIcon(thumbnail);
        }

        Notification notification = builder
                .clearActions()
                .addAction(
                        drawable.ic_media_previous,
                        "Previous",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(MediaControlReceiver.PREVIOUS_ACTION),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                )
                .addAction(
                        player.isPlaying() ? drawable.ic_media_pause : drawable.ic_media_play,
                        player.isPlaying() ? "Pause" : "Resume",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(
                                        player.isPlaying()
                                                ? MediaControlReceiver.PAUSE_ACTION
                                                : MediaControlReceiver.RESUME_ACTION
                                ),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                )
                .addAction(
                        drawable.ic_media_next,
                        "Next",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(MediaControlReceiver.NEXT_ACTION),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                )
                .setContentIntent(getPlayingScreenPendingIntent())
                .setContentText(
                        player.getCurrentMediaItem() != null
                                ? player.getCurrentMediaItem().mediaMetadata.artist
                                : null
                )
                .setContentTitle(
                        player.getCurrentMediaItem() != null
                                ? player.getCurrentMediaItem().mediaMetadata.title
                                : null
                )
                .setOngoing(player.isPlaying())
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setShowWhen(false)
                .setSmallIcon(drawable.ic_media_play)
                .setStyle(
                        new MediaStyleNotificationHelper.MediaStyle(mediaSession)
                                .setShowActionsInCompactView(0, 1, 2)
                                .setShowCancelButton(true)
                )
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build();

        startForeground(NOTIFICATION_ID, notification);
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private void createNotificationChannel() {
        NotificationChannel notificationChannel = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
        );
        notificationChannel.setDescription("MP3 Player Notification channel");
        notificationChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        notificationChannel.setShowBadge(false);

        NotificationManager notificationManager = getSystemService(NotificationManager.class);
        notificationManager.createNotificationChannel(notificationChannel);
    }
}
