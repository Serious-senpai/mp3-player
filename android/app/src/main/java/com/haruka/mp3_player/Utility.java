package com.haruka.mp3_player;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;

import androidx.annotation.ColorInt;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.IOException;
import java.net.URL;
import java.net.URLConnection;
import java.util.HashSet;
import java.util.Locale;

import io.flutter.Log;

public class Utility {
    public static class ThreadingTask<T> implements Runnable {
        public interface Task<T> {
            T run() throws Throwable;
        }

        public interface Callback<T> {
            void run(T param);
        }

        @NonNull
        private final Task<T> target;
        @NonNull
        private final HashSet<Callback<T>> onDone = new HashSet<>();
        @NonNull
        private final HashSet<Callback<Throwable>> onError = new HashSet<>();
        @NonNull
        private final HashSet<Runnable> onDoneNoParam = new HashSet<>();
        @NonNull
        private final HashSet<Runnable> onErrorNoParam = new HashSet<>();

        private boolean finished = false;
        private boolean success = false;
        @Nullable
        private T result = null;
        @Nullable
        private Throwable error = null;

        public ThreadingTask(@NonNull Task<T> target) {
            this.target = target;
        }

        public boolean isFinished() {
            return finished;
        }

        public ThreadingTask<T> addDoneCallback(@NonNull Callback<T> callback) {
            onDone.add(callback);
            if (finished && success) ignoreException(() -> callback.run(result));

            return this;
        }

        public ThreadingTask<T> addDoneCallback(@NonNull Runnable callback) {
            onDoneNoParam.add(callback);
            if (finished && success) ignoreException(callback);

            return this;
        }

        public ThreadingTask<T> addErrorCallback(@NonNull Callback<Throwable> callback) {
            onError.add(callback);
            if (finished && !success) ignoreException(() -> callback.run(error));

            return this;
        }

        public ThreadingTask<T> addErrorCallback(@NonNull Runnable callback) {
            onErrorNoParam.add(callback);
            if (finished && !success) ignoreException(callback);

            return this;
        }

        public synchronized void run() {
            if (!finished) {
                new Thread(
                        () -> {
                            try {
                                result = target.run();
                                success = true;
                            } catch (Throwable throwable) {
                                finished = true;
                                error = throwable;
                                for (Callback<Throwable> callback : onError)
                                    ignoreException(() -> callback.run(error));

                                for (Runnable callback : onErrorNoParam) ignoreException(callback);
                            } finally {
                                finished = true;
                            }

                            if (success) {
                                for (Callback<T> callback : onDone)
                                    ignoreException(() -> callback.run(result));

                                for (Runnable callback : onDoneNoParam) ignoreException(callback);
                            }
                        }
                ).start();
            }
        }

        private void ignoreException(@NonNull Runnable target) {
            try {
                target.run();
            } catch (Throwable ignored) {
            }
        }
    }

    public enum LogLevel {
        DEBUG,
        INFO,
        ERROR,
    }

    private static final String LOG_TAG = "HARUKA.MP3_PLAYER.NATIVE";

    public static void log(@NonNull LogLevel logLevel, @NonNull String content) {
        switch (logLevel) {
            case DEBUG:
                Log.d(LOG_TAG, content);
                break;

            case INFO:
                Log.i(LOG_TAG, content);
                break;

            case ERROR:
                Log.e(LOG_TAG, content);
        }
    }

    @NonNull
    public static String format(@NonNull String format, Object... args) {
        return String.format(Locale.US, format, args);
    }

    @NonNull
    public static String format(int bytes) {
        int abs = bytes > 0 ? bytes : -bytes;

        if (abs > (1 << 30)) {
            return format("%.2f GB", (double) bytes / (2 << 30));
        }

        if (abs > (1 << 20)) {
            return format("%.2f MB", (double) bytes / (2 << 20));
        }

        if (abs > (1 << 10)) {
            return format("%.2f KB", (double) bytes / (2 << 20));
        }

        return format("%d B", bytes);
    }

    @ColorInt
    public static int getDominantColor(@NonNull Bitmap bitmap) {
        Bitmap scaled = Bitmap.createScaledBitmap(bitmap, 1, 1, true);
        int color = scaled.getPixel(0, 0);
        scaled.recycle();
        return color;
    }

    // https://stackoverflow.com/questions/3035692/how-to-convert-a-drawable-to-a-bitmap/10600736#10600736
    @NonNull
    public static Bitmap drawableToBitmap(@NonNull Drawable drawable) {
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
    public static Bitmap bitmapFromUrl(@NonNull URL url) throws IOException {
        log(LogLevel.INFO, format("Loading bitmap from %s", url));
        URLConnection connection = url.openConnection();
        connection.connect();

        log(LogLevel.INFO, format("Connected to %s", url));
        return BitmapFactory.decodeStream(connection.getInputStream());
    }
}