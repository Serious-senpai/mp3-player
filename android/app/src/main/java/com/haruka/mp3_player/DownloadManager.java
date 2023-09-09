package com.haruka.mp3_player;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;

import java.io.BufferedInputStream;
import java.io.FileOutputStream;
import java.net.URL;
import java.net.URLConnection;

public class DownloadManager {
    private static final String NOTIFICATION_CHANNEL_ID = "mp3_player/dnc";
    private static final String NOTIFICATION_CHANNEL_NAME = "DownloaderNotificationChannel";

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

    private int progress = -1;
    private int total = -1;
    private static int notificationId = 2;

    public DownloadManager(
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

        // https://stackoverflow.com/a/15758953
        this.task = new Utility.ThreadingTask<>(
                () -> {
                    URLConnection connection = url.openConnection();
                    connection.connect();

                    total = connection.getContentLength();
                    BufferedInputStream input = new BufferedInputStream(url.openStream(), 4096);
                    FileOutputStream output = new FileOutputStream(outputFilePath);

                    progress = 0;
                    byte[] writer = new byte[1024];
                    int chunk;
                    while ((chunk = input.read(writer)) != -1) {
                        progress += chunk;
                        output.write(writer, 0, chunk);
                        createNotification();
                    }

                    output.flush();
                    output.close();
                    input.close();

                    return true;
                }
        ).addDoneCallback(
                () -> {
                    createNotification();
                    notificationId++;
                }
        ).addErrorCallback(
                (error) -> Utility.log(
                        Utility.LogLevel.ERROR,
                        Utility.format("Error downloading from %s: %s", url, error.toString())
                )
        );
    }

    private void createNotification() {
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel();
            builder = new Notification.Builder(context, NOTIFICATION_CHANNEL_ID);
        } else {
            builder = new Notification.Builder(context);
        }

        builder.setContentTitle(description)
                .setOngoing(!task.isFinished())
                .setPriority(Notification.PRIORITY_LOW)
                .setVisibility(Notification.VISIBILITY_PUBLIC);

        if (!task.isFinished()) {
            if (total > -1) {
                builder.setProgress(total, progress, false);
            } else {
                builder.setContentText(Utility.format("Downloaded %s", Utility.format(progress)));
            }
        } else {
            builder.setContentText("Download completed");
        }

        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        notificationManager.notify(notificationId, builder.build());
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
