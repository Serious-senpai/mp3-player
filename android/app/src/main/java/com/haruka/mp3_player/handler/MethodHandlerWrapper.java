package com.haruka.mp3_player.handler;

import androidx.annotation.NonNull;
import androidx.annotation.UiThread;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * A {@link MethodChannel.MethodCallHandler} that automatically handles any exceptions thrown when responding
 * to a method call from Dart.
 */
public class MethodHandlerWrapper implements MethodChannel.MethodCallHandler {
    /**
     * Similar to a {@link MethodChannel.MethodCallHandler} excepts that its {@link #onMethodCall(MethodCall, MethodChannel.Result)} is allowed to
     * throw any {@link Exception}.
     *
     * @see MethodChannel.MethodCallHandler
     */
    public interface ThrowableMethodHandler {
        /**
         * The method handler, similar to {@link MethodChannel.MethodCallHandler#onMethodCall(MethodCall, MethodChannel.Result)}.
         *
         * @param method A {@link MethodCall}.
         * @param result A {@link MethodChannel.Result} used for submitting the result of the call.
         * @throws Exception Any exceptions that occurred during the method handling process.
         * @see MethodChannel.MethodCallHandler#onMethodCall(MethodCall, MethodChannel.Result)
         */
        @UiThread
        void onMethodCall(@NonNull MethodCall method, @NonNull MethodChannel.Result result) throws Exception;
    }

    @NonNull
    private final ThrowableMethodHandler inner;

    /**
     * Initialize a new {@link MethodHandlerWrapper} that wraps a {@link ThrowableMethodHandler}
     *
     * @param handler The inner {@link ThrowableMethodHandler}
     */
    public MethodHandlerWrapper(@NonNull ThrowableMethodHandler handler) {
        inner = handler;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall method, @NonNull MethodChannel.Result result) {
        try {
            inner.onMethodCall(method, result);
        } catch (Exception error) {
            error.printStackTrace();
            result.error(error.getClass().getName(), error.getMessage(), error.getCause());
        }
    }
}
