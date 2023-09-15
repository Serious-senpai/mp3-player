package com.haruka.mp3_player.handler;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MediaMetadata;
import androidx.media3.common.Player;

import com.haruka.mp3_player.MediaPlayerService;
import com.haruka.mp3_player.Utility;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Objects;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * A {@link FlutterPlugin} that handles audio playback requests.
 */
public class MediaPlayerHandler extends AbstractMethodChannelPlugin {
    public class PlayerStateReceiver extends BroadcastReceiver {
        public static final String UPDATE_STATE_ACTION = "com.haruka.mp3_player.UPDATE_STATE_ACTION";
        public static final String INDEX_KEY = "INDEX";
        public static final String CURRENT_POSITION_KEY = "CURRENT_POSITION";
        public static final String DURATION_KEY = "DURATION";
        public static final String IS_PLAYING_KEY = "IS_PLAYING";
        public static final String PLAYLIST_ID_KEY = "PLAYLIST_ID";
        public static final String REPEAT_KEY = "REPEAT";
        public static final String SHUFFLE_KEY = "SHUFFLE";

        public static final String UPDATE_STATE_CHANNEL_METHOD = "UPDATE_STATE_CHANNEL_METHOD";

        @Override
        public void onReceive(Context context, Intent intent) {
            assert Objects.equals(intent.getAction(), UPDATE_STATE_ACTION);
            if (channel != null) {
                HashMap<String, Object> data = new HashMap<>();
                data.put(CURRENT_POSITION_KEY, intent.getLongExtra(CURRENT_POSITION_KEY, 0));
                data.put(DURATION_KEY, intent.getLongExtra(DURATION_KEY, 0));
                data.put(INDEX_KEY, intent.getIntExtra(INDEX_KEY, 0));
                data.put(IS_PLAYING_KEY, intent.getBooleanExtra(IS_PLAYING_KEY, false));
                data.put(PLAYLIST_ID_KEY, intent.getIntExtra(PLAYLIST_ID_KEY, -1));
                data.put(REPEAT_KEY, intent.getIntExtra(REPEAT_KEY, Player.REPEAT_MODE_OFF));
                data.put(SHUFFLE_KEY, intent.getBooleanExtra(SHUFFLE_KEY, false));

                channel.invokeMethod(UPDATE_STATE_CHANNEL_METHOD, data);
            }
        }
    }

    @NonNull
    private final PlayerStateReceiver receiver = new PlayerStateReceiver();

    /**
     * Initialize a new {@link MediaPlayerHandler}
     *
     * @param flutterActivity The {@link FlutterActivity} that registers this plugin.
     */
    public MediaPlayerHandler(@NonNull FlutterActivity flutterActivity) {
        super(flutterActivity, "com.haruka.mp3_player/player");
    }

    @Override
    protected void handler(@NonNull MethodCall method, @NonNull MethodChannel.Result result, @NonNull FlutterPluginBinding binding) throws Exception {
        Context context = binding.getApplicationContext();
        Intent intent = new Intent(), serviceIntent = new Intent(context, MediaPlayerService.class);
        switch (method.method) {
            case "play":
                JSONArray tracks = method.argument("tracks");
                assert tracks != null;

                Integer playlistId = method.argument("playlistId");
                assert playlistId != null;

                Integer index = method.argument("index");
                assert index != null;

                serviceIntent.setAction(MediaPlayerService.MediaControlReceiver.PLAY_ACTION);
                serviceIntent.putExtra(MediaPlayerService.MediaControlReceiver.PLAYLIST_ID_KEY, playlistId);
                serviceIntent.putExtra(MediaPlayerService.MediaControlReceiver.INITIAL_INDEX_KEY, index);

                ArrayList<Bundle> bundles = new ArrayList<>();
                for (int i = 0; i < tracks.length(); i++) {
                    JSONObject data = tracks.getJSONObject(i);
                    String uri = data.getString("uri");
                    String thumbnailUri = null;
                    try {
                        assert !data.isNull("thumbnailPath");
                        thumbnailUri = data.getString("thumbnailPath");
                    } catch (AssertionError ignored) {
                    }

                    String artist = null;
                    try {
                        assert !data.isNull("artist");
                        artist = data.getString("artist");
                    } catch (AssertionError ignored) {
                    }

                    String title = data.getString("title");

                    MediaItem mediaItem = new MediaItem.Builder()
                            .setMediaMetadata(
                                    new MediaMetadata.Builder()
                                            .setArtist(artist)
                                            .setArtworkUri(thumbnailUri != null ? Utility.uriFromFile(thumbnailUri) : null)
                                            .setMediaType(MediaMetadata.MEDIA_TYPE_MUSIC)
                                            .setTitle(title)
                                            .build()
                            )
                            .setRequestMetadata(
                                    new MediaItem.RequestMetadata.Builder()
                                            .setMediaUri(Utility.uriFromFile(uri))
                                            .build()
                            )
                            .setUri(uri)
                            .build();

                    bundles.add(mediaItem.toBundle());
                }

                Bundle bundle = new Bundle();
                bundle.putParcelableArrayList(MediaPlayerService.MediaControlReceiver.PLAYLIST_BUNDLE_LIST_KEY, bundles);
                serviceIntent.putExtra(MediaPlayerService.MediaControlReceiver.PLAYLIST_BUNDLE_KEY, bundle);

                flutterActivity.startService(serviceIntent);
                result.success(null);
                break;

            case "pause":
                intent.setAction(MediaPlayerService.MediaControlReceiver.PAUSE_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "resume":
                intent.setAction(MediaPlayerService.MediaControlReceiver.RESUME_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "seek":
                intent.setAction(MediaPlayerService.MediaControlReceiver.SEEK_ACTION);

                Integer seekPosition = method.argument("positionMs");
                assert seekPosition != null;
                intent.putExtra(MediaPlayerService.MediaControlReceiver.POSITION_MS_KEY, seekPosition);

                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "next":
                intent.setAction(MediaPlayerService.MediaControlReceiver.NEXT_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "previous":
                intent.setAction(MediaPlayerService.MediaControlReceiver.PREVIOUS_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "stop":
                intent.setAction(MediaPlayerService.MediaControlReceiver.STOP_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "toggleRepeat":
                intent.setAction(MediaPlayerService.MediaControlReceiver.SWITCH_REPEAT_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            case "toggleShuffle":
                intent.setAction(MediaPlayerService.MediaControlReceiver.SWITCH_SHUFFLE_ACTION);
                context.sendBroadcast(intent);
                result.success(null);
                break;

            default:
                result.notImplemented();
        }
    }

    @Override
    protected void whenAttachedToEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        IntentFilter intentFilter = new IntentFilter(PlayerStateReceiver.UPDATE_STATE_ACTION);
        binding.getApplicationContext().registerReceiver(receiver, intentFilter);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPlugin.FlutterPluginBinding binding) {
        binding.getApplicationContext().unregisterReceiver(receiver);
    }
}
