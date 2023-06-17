package com.haruka.mp3_player.handler;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.webkit.MimeTypeMap;
import androidx.annotation.NonNull;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.JSONMethodCodec;
import io.flutter.plugin.common.MethodChannel;

public class UtilsHandler implements FlutterPlugin {
    @NonNull
    private final FlutterActivity activity;

    public UtilsHandler(@NonNull FlutterActivity flutterActivity) {
        activity = flutterActivity;
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        new MethodChannel(binding.getBinaryMessenger(), "com.haruka.mp3_player/utils", JSONMethodCodec.INSTANCE)
                .setMethodCallHandler(
                        new MethodHandlerWrapper(
                                (method, result) -> {
                                    switch (method.method) {
                                        case "getMimeTypeFromExtension":
                                            String extension = method.argument("extension");
                                            HashMap<String, String> extensionData = new HashMap<>();
                                            extensionData.put("mimetype", MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension));

                                            result.success(extensionData);
                                            break;

                                        case "launchUri":
                                            Uri browserUri = Uri.parse(method.argument("uri"));
                                            Intent browserIntent = new Intent(Intent.ACTION_VIEW, browserUri);
                                            activity.startActivity(browserIntent);
                                            result.success(null);
                                            break;

                                        case "getDataDirectory":
                                            HashMap<String, String> dataDirectory = new HashMap<>();
                                            dataDirectory.put("path", Environment.getDataDirectory().getAbsolutePath());

                                            result.success(dataDirectory);
                                            break;

                                        case "getDownloadCacheDirectory":
                                            HashMap<String, String> downloadCacheDirectory = new HashMap<>();
                                            downloadCacheDirectory.put("path", Environment.getDownloadCacheDirectory().getAbsolutePath());

                                            result.success(downloadCacheDirectory);
                                            break;

                                        case "getExternalStorageDirectory":
                                            HashMap<String, String> externalStorageDirectory = new HashMap<>();
                                            externalStorageDirectory.put("path", Environment.getExternalStorageDirectory().getAbsolutePath());

                                            result.success(externalStorageDirectory);
                                            break;

                                        case "getStorageDirectory":
                                            HashMap<String, String> storageDirectory = new HashMap<>();
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                                storageDirectory.put("path", Environment.getStorageDirectory().getAbsolutePath());
                                            }

                                            result.success(storageDirectory);
                                            break;

                                        case "getExternalFilesDirs":
                                            HashMap<String, ArrayList<String>> externalFilesDirs = new HashMap<>();
                                            ArrayList<String> paths = new ArrayList<>();
                                            for (File file: context.getExternalFilesDirs(null)){
                                                paths.add(file.getAbsolutePath());
                                            }
                                            externalFilesDirs.put("paths", paths);

                                            result.success(externalFilesDirs);
                                            break;

                                        default:
                                            result.notImplemented();
                                    }
                                }
                        )
                );
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
