package com.haruka.mp3_player;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.R.drawable;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import java.io.BufferedInputStream;
import java.io.FileOutputStream;
import java.net.URL;
import java.net.URLConnection;

public class DownloadController {
    private static final int NOTIFICATION_ID = 1;
    private static final String NOTIFICATION_CHANNEL_ID = "mp3_player/dnc";
    private static final String NOTIFICATION_CHANNEL_NAME = "DownloaderNotificationChannel";
    private static final int NOTIFICATION_UPDATE_PERIOD_MS = 500;

    @NonNull
    public final URL url;
    @NonNull
    public final String outputFilePath;
    @NonNull
    public final URL iconUrl;
    @NonNull
    public final String description;
    @NonNull
    public final Context context;
    @NonNull
    public final Utility.ThreadingTask<Boolean> task;

    @NonNull
    private final NotificationCompat.Builder builder;
    private int progress = -1;
    private int total = -1;
    private static int completedNotificationId = 2;

    public DownloadController(
            @NonNull URL url,
            @NonNull String outputFilePath,
            @NonNull URL iconUrl,
            @NonNull String description,
            @NonNull Context context
    ) {
        this.url = url;
        this.outputFilePath = outputFilePath;
        this.iconUrl = iconUrl;
        this.description = description;
        this.context = context;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel();
        }
        builder = new NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID);

        // https://stackoverflow.com/a/15758953
        task = new Utility.ThreadingTask<>(
                () -> {
                    Utility.log(Utility.format("Downloading %s from %s to %s", description, url, outputFilePath));

                    URLConnection connection = url.openConnection();
                    connection.connect();

                    total = connection.getContentLength();
                    BufferedInputStream input = new BufferedInputStream(url.openStream(), 4096);
                    FileOutputStream output = new FileOutputStream(outputFilePath);

                    progress = 0;
                    byte[] writer = new byte[1024];
                    int chunk;

                    long timer = System.currentTimeMillis();
                    boolean notifyCompletion = false;
                    while ((chunk = input.read(writer)) != -1) {
                        progress += chunk;
                        output.write(writer, 0, chunk);
                        if (System.currentTimeMillis() - timer > NOTIFICATION_UPDATE_PERIOD_MS) {
                            notifyCompletion = notifyCompletion || updateNotification();
                            timer = System.currentTimeMillis();
                        }
                    }

                    output.flush();
                    output.close();
                    input.close();

                    if (!notifyCompletion) updateNotification();

                    return true;
                }
        )
                .addDoneCallback(this::updateNotification)
                .addErrorCallback(
                        (error) -> Utility.log(
                                Utility.LogLevel.ERROR,
                                Utility.format("Error downloading %s from %s: %s", description, url, error.toString())
                        )
                ).addErrorCallback(
                        () -> {
                            builder.setContentText("Download failed")
                                    .setOngoing(false)
                                    .setProgress(0, 0, false)
                                    .setSmallIcon(drawable.stat_sys_download_done);

                            showNotification(completedNotificationId);
                            completedNotificationId++;

                            NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
                            notificationManager.cancel(NOTIFICATION_ID);
                        }
                );

        builder.setContentTitle(description)
                .setOnlyAlertOnce(true)
                .setPriority(Notification.PRIORITY_LOW)
                .setSmallIcon(drawable.stat_sys_download)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

        builder.setColor(Color.CYAN);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setColorized(true);
        }

        new Utility.ThreadingTask<>(() -> Utility.bitmapFromUrl(iconUrl))
                .addDoneCallback(builder::setLargeIcon)
                .addErrorCallback(
                        (error) -> {
                            error.printStackTrace();
                            try {
                                String packageName = context.getPackageName();
                                PackageManager packageManager = context.getPackageManager();
                                builder.setLargeIcon(Utility.drawableToBitmap(packageManager.getApplicationIcon(packageName)));
                            } catch (PackageManager.NameNotFoundException e) {
                                e.printStackTrace();
                            }
                        }
                )
                .run();
    }

    private synchronized boolean updateNotification() {
        if (task.isFinished()) {
            builder.setContentText(Utility.format("Download completed (%s)", Utility.format(progress)))
                    .setOngoing(false)
                    .setProgress(0, 0, false)
                    .setSmallIcon(drawable.stat_sys_download_done);

            showNotification(completedNotificationId);
            completedNotificationId++;

            NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            notificationManager.cancel(NOTIFICATION_ID);

            return true;
        } else {
            builder.setOngoing(true);
            if (total > -1) {
                builder.setContentText(
                        Utility.format(
                                "Downloaded %s/%s (%.2f%%)",
                                Utility.format(progress),
                                Utility.format(total),
                                100.0 * (double) progress / (double) total
                        )
                ).setProgress(total, progress, false);
            } else {
                builder.setContentText(Utility.format("Downloaded %s", Utility.format(progress)));
            }

            showNotification(NOTIFICATION_ID);
            return false;
        }
    }

    private void showNotification(int id) {
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        notificationManager.notify(id, builder.build());
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private void createNotificationChannel() {
        NotificationChannel notificationChannel = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
        );
        notificationChannel.setDescription("Downloader Notification channel");
        notificationChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);

        NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
        notificationManager.createNotificationChannel(notificationChannel);
    }
}
