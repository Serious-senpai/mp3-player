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

public class MediaPlayerService extends Service {
    private static final int NOTIFICATION_ID = 1;
    private static final String NOTIFICATION_CHANNEL_ID = "mp3_player/notification.channel.id";
    private static final String NOTIFICATION_CHANNEL_NAME = "mp3_player/notification.channel.name";
    private static boolean started = false;

    private class NotificationUpdateReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            assert MediaPlayerImpl.UPDATE_NOTIFICATION_ACTION.equals(intent.getAction());
            displayNotification();
        }

        public void register(@NonNull Context context) {
            IntentFilter intentFilter = new IntentFilter(MediaPlayerImpl.UPDATE_NOTIFICATION_ACTION);
            context.registerReceiver(this, intentFilter);
        }

        public void unregister(@NonNull Context context) {
            context.unregisterReceiver(this);
        }
    }

    @Nullable
    private Notification.Builder notificationBuilder;

    private final MediaPlayerImpl player = MediaPlayerImpl.create();

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

    public static boolean started() {
        return started;
    }

    @NonNull
    private final NotificationUpdateReceiver receiver = new NotificationUpdateReceiver();

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        displayNotification();
        receiver.register(getApplicationContext());
        started = true;
        return super.onStartCommand(intent, flags, startId);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();

        Context context = getApplicationContext();
        receiver.unregister(context);
        MediaPlayerImpl player = MediaPlayerImpl.create();
        if (player.getContext() == context) {
            player.setContext(null);
        }
    }

    private void displayNotification() {
        if (player.currentTrack != null) {
            displayNotification(player.currentTrack);
        }
    }

    private void displayNotification(@NonNull TrackMetadata track) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel();
        }

        Context context = getApplicationContext();
        Bitmap thumbnail = BitmapFactory.decodeFile(track.thumbnailPath);

        createNotificationBuilder();
        assert notificationBuilder != null;
        notificationBuilder.setContentIntent(
                        PendingIntent.getActivity(
                                context, NOTIFICATION_ID,
                                new Intent(context, MainActivity.class),
                                PendingIntent.FLAG_IMMUTABLE
                        )
                )
                .setContentText(track.artist)
                .setContentTitle(track.title)
                .setOnlyAlertOnce(true)
                .setPriority(Notification.PRIORITY_MAX)
                .setShowWhen(false)
                .setStyle(new Notification.MediaStyle())
                .setVisibility(Notification.VISIBILITY_PUBLIC);

        if (thumbnail != null) {
            notificationBuilder.setColor(getDominantColor(thumbnail))
                    .setLargeIcon(thumbnail);
        } else {
            try {
                Drawable drawable = context.getPackageManager().getApplicationIcon(context.getPackageName());
                notificationBuilder.setLargeIcon(drawableToBitmap(drawable));
            } catch (PackageManager.NameNotFoundException error) {
                error.printStackTrace();
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationBuilder.setSmallIcon(drawable.stat_sys_headset);
        }

        Notification notification = notificationBuilder.build();
        startForeground(NOTIFICATION_ID, notification);
    }

    private void createNotificationBuilder() {
        if (notificationBuilder == null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                notificationBuilder = new Notification.Builder(getApplicationContext(), NOTIFICATION_CHANNEL_ID)
                        .setColorized(true);
            } else {
                notificationBuilder = new Notification.Builder(getApplicationContext());
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private void createNotificationChannel() {
        NotificationChannel notificationChannel = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
        );
        notificationChannel.setDescription("MP3 Player Notification channel");
        notificationChannel.setImportance(NotificationManager.IMPORTANCE_LOW);
        notificationChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        notificationChannel.setShowBadge(false);

        NotificationManager notificationManager = getSystemService(NotificationManager.class);
        notificationManager.createNotificationChannel(notificationChannel);
    }
}