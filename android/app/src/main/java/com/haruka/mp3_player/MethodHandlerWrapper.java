package com.haruka.mp3_player;

import androidx.annotation.NonNull;
import androidx.annotation.UiThread;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MethodHandlerWrapper implements MethodChannel.MethodCallHandler {
    public interface ThrowableMethodHandler{
        @UiThread
        void onMethodCall(@NonNull MethodCall method, @NonNull MethodChannel.Result result) throws Exception;
    }

    @NonNull
    private final ThrowableMethodHandler inner;

    MethodHandlerWrapper(@NonNull ThrowableMethodHandler handler){
        inner = handler;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall method, @NonNull MethodChannel.Result result){
        try{
            inner.onMethodCall(method, result);
        } catch (Exception error){
            error.printStackTrace();
            result.error(error.getClass().getName(), error.getMessage(), error.getCause());
        }
    }
}
