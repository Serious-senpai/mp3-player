package com.haruka.mp3_player.handler;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.haruka.mp3_player.MediaPlayerImpl;
import com.haruka.mp3_player.MediaPlayerService;

import org.json.JSONArray;
import java.util.HashMap;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.JSONMethodCodec;
import io.flutter.plugin.common.MethodChannel;

public class MediaPlayerHandler implements FlutterPlugin {
    private class PlayerStateReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, @NonNull Intent intent) {
            switch (intent.getAction()) {
                case MediaPlayerImpl.UPDATE_STATE_METHOD:
                    if (channel != null) {
                        HashMap<String, Object> data = new HashMap<>();
                        data.put(MediaPlayerImpl.CURRENT_POSITION_KEY, intent.getIntExtra(MediaPlayerImpl.CURRENT_POSITION_KEY, 0));
                        data.put(MediaPlayerImpl.DURATION_KEY, intent.getIntExtra(MediaPlayerImpl.DURATION_KEY, 0));
                        data.put(MediaPlayerImpl.INDEX_KEY, intent.getIntExtra(MediaPlayerImpl.INDEX_KEY, 0));
                        data.put(MediaPlayerImpl.IS_PLAYING_KEY, intent.getBooleanExtra(MediaPlayerImpl.IS_PLAYING_KEY, false));
                        data.put(MediaPlayerImpl.PLAYLIST_ID_KEY, intent.getIntExtra(MediaPlayerImpl.PLAYLIST_ID_KEY, -1));
                        data.put(MediaPlayerImpl.REPEAT_KEY, intent.getBooleanExtra(MediaPlayerImpl.REPEAT_KEY, false));

                        channel.invokeMethod(MediaPlayerImpl.UPDATE_STATE_METHOD, data);
                    }
                    break;

                case MediaPlayerImpl.ON_COMPLETION_METHOD:
                    if (channel != null) {
                        channel.invokeMethod(MediaPlayerImpl.ON_COMPLETION_METHOD, null);
                    }
                    break;

                case MediaPlayerImpl.ON_ERROR_METHOD:
                    if (channel != null) {
                        HashMap<String, Object> data = new HashMap<>();
                        data.put("what", intent.getIntExtra("what", 0));
                        data.put("extra", intent.getIntExtra("extra", 0));

                        channel.invokeMethod(MediaPlayerImpl.ON_ERROR_METHOD, data);
                    }
                    break;

                case MediaPlayerImpl.ON_INFO_METHOD:
                    if (channel != null) {
                        HashMap<String, Object> data = new HashMap<>();
                        data.put("what", intent.getIntExtra("what", 0));
                        data.put("extra", intent.getIntExtra("extra", 0));

                        channel.invokeMethod(MediaPlayerImpl.ON_INFO_METHOD, data);
                    }
                    break;

                case MediaPlayerImpl.ON_PREPARED_METHOD:
                    if (channel != null) {
                        channel.invokeMethod(MediaPlayerImpl.ON_PREPARED_METHOD, null);
                    }
                    break;

                case MediaPlayerImpl.ON_SEEK_COMPLETE_METHOD:
                    if (channel != null) {
                        channel.invokeMethod(MediaPlayerImpl.ON_SEEK_COMPLETE_METHOD, null);
                    }
                    break;
            }
        }

        public void register(@NonNull Context context) {
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction(MediaPlayerImpl.UPDATE_STATE_METHOD);
            intentFilter.addAction(MediaPlayerImpl.ON_COMPLETION_METHOD);
            intentFilter.addAction(MediaPlayerImpl.ON_ERROR_METHOD);
            intentFilter.addAction(MediaPlayerImpl.ON_INFO_METHOD);
            intentFilter.addAction(MediaPlayerImpl.ON_PREPARED_METHOD);
            intentFilter.addAction(MediaPlayerImpl.ON_SEEK_COMPLETE_METHOD);
            context.registerReceiver(this, intentFilter);
        }

        public void unregister(@NonNull Context context) {
            context.unregisterReceiver(this);
        }
    }

    @Nullable
    private MethodChannel channel;
    @NonNull
    private final FlutterActivity activity;
    @NonNull
    private final MediaPlayerImpl player = MediaPlayerImpl.create();
    @NonNull
    private final PlayerStateReceiver receiver = new PlayerStateReceiver();

    /**
     * Initialize a new {@link MediaPlayerHandler}
     *
     * @param flutterActivity The {@link FlutterActivity} that registers this plugin.
     */
    public MediaPlayerHandler(@NonNull FlutterActivity flutterActivity) {
        activity = flutterActivity;
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        receiver.register(context);
        player.setContext(context);
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.haruka.mp3_player/player", JSONMethodCodec.INSTANCE);
        channel.setMethodCallHandler(
                new MethodHandlerWrapper(
                        (method, result) -> {
                            Intent serviceIntent = new Intent(context, MediaPlayerService.class);
                            switch (method.method) {
                                case "play":
                                    JSONArray playTracks = method.argument("tracks");
                                    assert playTracks != null;
                                    player.setTracks(playTracks);

                                    Integer playPlaylistId = method.argument("playlistId");
                                    assert playPlaylistId != null;
                                    player.setPlaylistId(playPlaylistId);

                                    Integer playIndex = method.argument("index");
                                    assert playIndex != null;
                                    player.setIndex(playIndex);

                                    player.play();
                                    activity.startService(serviceIntent);
                                    result.success(null);
                                    break;

                                case "pause":
                                    player.pause();
                                    result.success(null);
                                    break;

                                case "resume":
                                    player.resume();
                                    result.success(null);
                                    break;

                                case "seek":
                                    Integer duration = method.argument("duration");
                                    assert duration != null;
                                    player.seekTo(duration);
                                    result.success(null);
                                    break;

                                case "next":
                                    player.next();
                                    result.success(null);
                                    break;

                                case "previous":
                                    player.previous();
                                    result.success(null);
                                    break;

                                case "stop":
                                    player.stop();
                                    result.success(null);
                                    context.stopService(serviceIntent);
                                    break;

                                case "toggleRepeat":
                                    player.toggleRepeat();
                                    result.success(null);
                                    break;

                                case "update":
                                    // Update these attributes while not playing doesn't affect anything
                                    JSONArray updateTracks = method.argument("tracks");
                                    if (updateTracks != null) {
                                        player.setTracks(updateTracks);
                                    }

                                    Integer updatePlaylistId = method.argument("playlistId");
                                    if (updatePlaylistId != null) {
                                        player.setPlaylistId(updatePlaylistId);
                                    }

                                    Integer updateIndex = method.argument("index");
                                    if (updateIndex != null) {
                                        player.setIndex(updateIndex);
                                    }

                                    result.success(null);
                                    break;

                                default:
                                    result.notImplemented();
                            }
                        }
                )
        );
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        receiver.unregister(context);
        if (player.getContext() == context) {
            player.setContext(null);
        }
    }
}
