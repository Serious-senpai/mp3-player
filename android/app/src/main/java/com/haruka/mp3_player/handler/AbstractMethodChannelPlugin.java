package com.haruka.mp3_player.handler;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.haruka.mp3_player.Utility;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.JSONMethodCodec;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public abstract class AbstractMethodChannelPlugin implements FlutterPlugin {
    @Nullable
    protected MethodChannel channel;
    @NonNull
    protected final String channelName;
    @NonNull
    protected final FlutterActivity flutterActivity;

    protected AbstractMethodChannelPlugin(@NonNull FlutterActivity flutterActivity, @NonNull String channelName) {
        this.flutterActivity = flutterActivity;
        this.channelName = channelName;
    }

    protected abstract void handler(MethodCall method, MethodChannel.Result result, FlutterPluginBinding binding) throws Throwable;

    protected abstract void whenAttachedToEngine(@NonNull FlutterPluginBinding binding);

    @Override
    public final void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        whenAttachedToEngine(binding);
        channel = new MethodChannel(binding.getBinaryMessenger(), channelName, JSONMethodCodec.INSTANCE);
        channel.setMethodCallHandler(
                (method, result) -> {
                    try {
                        handler(method, result, binding);
                    } catch (Throwable error) {
                        sendError(result, error);
                    }
                }
        );
    }

    public void sendError(MethodChannel.Result result, Throwable error) {
        error.printStackTrace();
        Utility.log(Utility.LogLevel.ERROR, error.toString());
        result.error(error.getClass().getName(), error.getMessage(), error.getCause());
    }
}
