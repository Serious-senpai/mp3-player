package com.haruka.mp3_player.handler;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.webkit.MimeTypeMap;
import android.widget.Toast;

import androidx.annotation.NonNull;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * A {@link FlutterPlugin} for utilities functions
 */
public class UtilsHandler extends AbstractMethodChannelPlugin {
    /**
     * Initialize a new {@link UtilsHandler}
     *
     * @param flutterActivity The {@link FlutterActivity} that registers this plugin.
     */
    public UtilsHandler(@NonNull FlutterActivity flutterActivity) {
        super(flutterActivity, "com.haruka.mp3_player/utils");
    }

    @Override
    protected void handler(@NonNull MethodCall method, @NonNull MethodChannel.Result result, @NonNull FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        switch (method.method) {
            case "getSDKVersion":
                HashMap<String, Integer> sdkData = new HashMap<>();
                sdkData.put("SDK", Build.VERSION.SDK_INT);
                result.success(sdkData);
                break;

            case "getMimeTypeFromExtension":
                String extension = method.argument("extension");
                HashMap<String, String> extensionData = new HashMap<>();
                extensionData.put("mimeType", MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension));

                result.success(extensionData);
                break;

            case "launchUri":
                Uri browserUri = Uri.parse(method.argument("uri"));
                Intent browserIntent = new Intent(Intent.ACTION_VIEW, browserUri);
                flutterActivity.startActivity(browserIntent);
                result.success(null);
                break;

            case "getExternalFilesDirs":
                HashMap<String, ArrayList<String>> externalFilesDirs = new HashMap<>();
                ArrayList<String> paths = new ArrayList<>();
                for (File file : context.getExternalFilesDirs(null)) {
                    paths.add(file.getAbsolutePath());
                }
                externalFilesDirs.put("paths", paths);

                result.success(externalFilesDirs);
                break;

            case "shareFile":
                Uri shareUri = Uri.parse(method.argument("path"));
                String mimeType = method.argument("mimeType");

                Intent shareIntent = new Intent(Intent.ACTION_SEND);
                shareIntent.setType(Intent.normalizeMimeType(mimeType == null ? "*/*" : mimeType));
                shareIntent.putExtra(Intent.EXTRA_STREAM, shareUri);

                flutterActivity.startActivity(Intent.createChooser(shareIntent, "Share this file"));
                result.success(null);
                break;

            case "showToast":
                String content = method.argument("content");
                Toast.makeText(context, content, Toast.LENGTH_LONG).show();
                result.success(null);
                break;

            default:
                result.notImplemented();
        }
    }

    @Override
    protected void whenAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    }
}
