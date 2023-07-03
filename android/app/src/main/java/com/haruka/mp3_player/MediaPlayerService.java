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
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.IBinder;
import android.R.drawable;
import androidx.annotation.ColorInt;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

import io.flutter.embedding.android.FlutterActivity;

/**
 * The foreground {@link Service} which is responsible for displaying the notification to keep the
 * audio playing.
 */
public class MediaPlayerService extends Service {
    private static final int NOTIFICATION_ID = 1;
    private static final String NOTIFICATION_CHANNEL_ID = "mp3_player/notification.channel.id";
    private static final String NOTIFICATION_CHANNEL_NAME = "mp3_player/notification.channel.name";

    private abstract class NestedReceiver extends BroadcastReceiver {
        @NonNull
        protected abstract IntentFilter getIntentFilter();

        protected void register() {
            registerReceiver(this, getIntentFilter());
        }

        protected void unregister() {
            unregisterReceiver(this);
        }
    }

    private class NotificationUpdateReceiver extends NestedReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            assert MediaPlayerImpl.UPDATE_NOTIFICATION_ACTION.equals(intent.getAction());
            displayNotification();
        }

        @NonNull
        @Override
        protected IntentFilter getIntentFilter() {
            return new IntentFilter(MediaPlayerImpl.UPDATE_NOTIFICATION_ACTION);
        }
    }

    private class MediaPlayerReceiver extends NestedReceiver {
        public static final String NEXT_ACTION = "com.haruka.mp3_player.NEXT";
        public static final String PAUSE_ACTION = "com.haruka.mp3_player.PAUSE";
        public static final String PREVIOUS_ACTION = "com.haruka.mp3_player.PREVIOUS";
        public static final String RESUME_ACTION = "com.haruka.mp3_player.RESUME";

        @Override
        public void onReceive(Context context, @NonNull Intent intent) {
            if (player != null) {
                switch (intent.getAction()) {
                    case NEXT_ACTION:
                        player.next(context);
                        break;

                    case PAUSE_ACTION:
                        player.pause(context);
                        break;

                    case PREVIOUS_ACTION:
                        player.previous(context);
                        break;

                    case RESUME_ACTION:
                        player.resume(context);
                        break;
                }
            }
        }

        @NonNull
        @Override
        protected IntentFilter getIntentFilter() {
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction(NEXT_ACTION);
            intentFilter.addAction(PAUSE_ACTION);
            intentFilter.addAction(PREVIOUS_ACTION);
            intentFilter.addAction(RESUME_ACTION);

            return intentFilter;
        }
    }

    @Nullable
    private MediaPlayerImpl player;

    @NonNull
    private final MediaPlayerReceiver mediaPlayerReceiver = new MediaPlayerReceiver();

    @NonNull
    private final NotificationUpdateReceiver receiver = new NotificationUpdateReceiver();

    @ColorInt
    private static int getDominantColor(@NonNull Bitmap bitmap) {
        Bitmap scaled = Bitmap.createScaledBitmap(bitmap, 1, 1, true);
        int color = scaled.getPixel(0, 0);
        scaled.recycle();
        return color;
    }

    // https://stackoverflow.com/questions/3035692/how-to-convert-a-drawable-to-a-bitmap/10600736#10600736
    @NonNull
    private static Bitmap drawableToBitmap(@NonNull Drawable drawable) {
        Bitmap bitmap;
        if (drawable instanceof BitmapDrawable) {
            BitmapDrawable bitmapDrawable = (BitmapDrawable) drawable;
            bitmap = bitmapDrawable.getBitmap();
            if (bitmap != null) {
                return bitmap;
            }
        }

        if (drawable.getIntrinsicWidth() <= 0 || drawable.getIntrinsicHeight() <= 0) {
            bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888); // Single color bitmap will be created of 1x1 pixel
        } else {
            bitmap = Bitmap.createBitmap(drawable.getIntrinsicWidth(), drawable.getIntrinsicHeight(), Bitmap.Config.ARGB_8888);
        }

        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }

    @NonNull
    private Bitmap getApplicationIcon() throws PackageManager.NameNotFoundException {
        Drawable drawable = getPackageManager().getApplicationIcon(getPackageName());
        return drawableToBitmap(drawable);
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        player = MediaPlayerImpl.create(getBaseContext());
        mediaPlayerReceiver.register();
        receiver.register();
        displayNotification();
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    public void onDestroy() {
        mediaPlayerReceiver.unregister();
        receiver.unregister();
        super.onDestroy();
    }

    private void displayNotification() {
        if (player != null && player.currentTrack != null) {
            displayNotification(player.currentTrack);
        }
    }

    private void displayNotification(@NonNull TrackMetadata track) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel();
        }

        // Get thumbnail to display
        @Nullable Bitmap thumbnail = null;
        if (track.thumbnailPath != null) {
            thumbnail = BitmapFactory.decodeFile(track.thumbnailPath);
        } else {
            try {
                thumbnail = getApplicationIcon();
            } catch (PackageManager.NameNotFoundException error) {
                error.printStackTrace();
            }
        }

        assert player != null;

        // Construct Notification.MediaStyle
        Notification.MediaStyle style = new Notification.MediaStyle();
        style.setShowActionsInCompactView(0, 1, 2);
        if (player.mediaSession != null) {
            style.setMediaSession(player.mediaSession.getSessionToken());
        }

        // Construct the list of Actions in the notification
        Notification.Action[] actions = {
                new Notification.Action.Builder(
                        drawable.ic_media_previous,
                        "Previous",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(MediaPlayerReceiver.PREVIOUS_ACTION),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                ).build(),
                player.isPlaying() ? new Notification.Action.Builder(
                        drawable.ic_media_pause,
                        "Pause",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(MediaPlayerReceiver.PAUSE_ACTION),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                ).build() : new Notification.Action.Builder(
                        drawable.ic_media_play,
                        "Resume",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(MediaPlayerReceiver.RESUME_ACTION),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                ).build(),
                new Notification.Action.Builder(
                        drawable.ic_media_next,
                        "Next",
                        PendingIntent.getBroadcast(
                                getApplicationContext(), 2,
                                new Intent(MediaPlayerReceiver.NEXT_ACTION),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                ).build(),
        };

        // Construct Notification.Builder
        Notification.Builder notificationBuilder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ?
                new Notification.Builder(getApplicationContext(), NOTIFICATION_CHANNEL_ID)
                        .setColorized(true)
                : new Notification.Builder(getApplicationContext());

        if (thumbnail != null) {
            notificationBuilder.setColor(getDominantColor(thumbnail))
                    .setLargeIcon(thumbnail);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            notificationBuilder.setActions(actions);
        } else {
            for (Notification.Action action : actions) {
                notificationBuilder.addAction(action);
            }
        }

        notificationBuilder.setContentIntent(
                        PendingIntent.getActivity(
                                getApplicationContext(), 1,
                                new FlutterActivity.NewEngineIntentBuilder(MainActivity.class)
                                        .initialRoute("/play")
                                        .build(getApplicationContext()),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                )
                .setContentText(track.artist != null ? track.artist : "Unknown artist")
                .setContentTitle(track.title)
                .setOngoing(player.isPlaying())
                .setOnlyAlertOnce(true)
                .setPriority(Notification.PRIORITY_MAX)
                .setShowWhen(false)
                .setStyle(style)
                .setVisibility(Notification.VISIBILITY_PUBLIC);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationBuilder.setSmallIcon(drawable.ic_media_play);
        }

        startForeground(NOTIFICATION_ID, notificationBuilder.build());
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
