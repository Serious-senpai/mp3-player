import "dart:io";

import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:path/path.dart";
import "package:permission_handler/permission_handler.dart";

import "channels.dart";
import "playlists.dart";
import "videos.dart";
import "../downloader.dart";
import "../utils.dart";

double _imageHeight(double width) => 9.0 * width / 16.0;

Future<String?> _selectDownloadLocation(BuildContext context, String dialogTitle) async {
  var directories = await getExternalFilesDirs() ?? [];

  if (context.mounted) {
    var rootDirectory = await showDialog<Directory>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: DropdownButtonFormField<Directory>(
          items: List<DropdownMenuItem<Directory>>.generate(
            directories.length,
            (index) => DropdownMenuItem<Directory>(
              value: directories[index],
              child: Text(
                directories[index].path,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          hint: const Text("Select download location"),
          isExpanded: true,
          onChanged: (value) => Navigator.pop(context, value),
        ),
      ),
    );

    if (context.mounted && rootDirectory != null) {
      return await FilesystemPicker.openDialog(
        context: context,
        fsType: FilesystemType.folder,
        requestPermission: () async {
          var status = await Permission.storage.request();
          return status.isGranted;
        },
        rootDirectory: rootDirectory,
        showGoUp: true,
        title: "Select download location",
      );
    }
  }

  return null;
}

Future<void> _downloadVideoFromUrl(PartialVideo video, String pickedPath, String? url) async {
  var fileName = "${removeReservedCharacters(video.title)}.mp3";
  if (url == null) {
    await showToast("Cannot download ${video.title}");
  } else {
    await showToast("Downloading ${video.title}");
    await download(
      url: url,
      outputFilePath: join(pickedPath, fileName),
      iconUrl: video.thumbnailUri.toString(),
      description: video.title,
    );
    await showToast("Downloaded to $fileName");
  }
}

Future<void> tapToDownloadVideo(BuildContext context, Video video) async {
  var urlFuture = video.getAudioUrl();
  var pickedPath = await _selectDownloadLocation(context, "Download video");

  if (pickedPath != null) {
    await _downloadVideoFromUrl(video, pickedPath, await urlFuture);
  }
}

Future<void> tapToDownloadPlaylist(BuildContext context, Playlist playlist) async {
  var pickedPath = await _selectDownloadLocation(context, "Download playlist");
  if (pickedPath == null) return;
  for (var video in playlist.videos) {
    var url = await video.getAudioUrl();
    if (url == null) {
      await showToast("Cannot download ${video.title}");
    } else {
      if (context.mounted) {
        await _downloadVideoFromUrl(video, pickedPath, url);
      }
    }
  }
}

class _ChannelAvatar extends StatelessWidget {
  final Future<Channel?> future;
  final void Function(Channel? channel)? onTap;

  const _ChannelAvatar({Key? key, required this.future, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return loadingIndicator(size: 18);
          case ConnectionState.done:
            var data = snapshot.data;
            return GestureDetector(
              onTap: () {
                var onTapLocal = onTap;
                if (onTapLocal != null) onTapLocal(data);
              },
              child: data == null
                  ? const Icon(Icons.error_outline, size: 18)
                  : CircleAvatar(
                      backgroundImage: NetworkImage(data.thumbnails[0].url.toString()),
                      radius: 18,
                    ),
            );

          default:
            return const Icon(Icons.error_outline, size: 18);
        }
      },
    );
  }
}

class _ThumbnailWidget extends StatelessWidget {
  final String? src;
  final double width;

  const _ThumbnailWidget(this.src, {Key? key, required this.width}) : super(key: key);

  double get height => _imageHeight(width);

  @override
  Widget build(BuildContext context) => src == null
      ? SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.error_outline)),
        )
      : Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(src!),
              fit: BoxFit.fitWidth,
              alignment: const Alignment(-1.0, 0.0),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          ),
          width: width,
          height: height,
        );
}

class VideoWidget extends StatelessWidget {
  final Video video;
  final Color? color;
  final Decoration? decoration;
  final double width;
  final void Function()? onTap;

  final Future<Channel?> _getChannelFuture;

  VideoWidget({
    Key? key,
    required this.video,
    this.color,
    this.decoration,
    required this.width,
    this.onTap,
  })  : _getChannelFuture = video.channel.toChannel(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
        color: color,
        decoration: decoration,
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ThumbnailWidget(video.thumbnailUri.toString(), width: width),
            Row(
              children: [
                _ChannelAvatar(
                  future: _getChannelFuture,
                  onTap: (channel) {
                    if (channel != null) {
                      Navigator.pushNamed(
                        context,
                        "/youtube/channel",
                        arguments: channel,
                      );
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          softWrap: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          video.channel.author,
                          softWrap: true,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistWidget extends StatelessWidget {
  final Playlist playlist;
  final Color? color;
  final Decoration? decoration;
  final double width;
  final void Function()? onTap;

  final Future<Channel?> _getChannelFuture;

  PlaylistWidget({
    Key? key,
    required this.playlist,
    this.color,
    this.decoration,
    required this.width,
    this.onTap,
  })  : _getChannelFuture = playlist.channel.toChannel(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
        color: color,
        decoration: decoration,
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ThumbnailWidget(playlist.thumbnailUri?.toString(), width: width),
            Row(
              children: [
                _ChannelAvatar(
                  future: _getChannelFuture,
                  onTap: (channel) {
                    if (channel != null) {
                      Navigator.pushNamed(
                        context,
                        "/youtube/channel",
                        arguments: channel,
                      );
                    }
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.title,
                          softWrap: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${playlist.channel.author} • ${playlist.videos.length} ${ngettext("video", "videos", playlist.videos.length)}",
                          softWrap: true,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChannelWidget extends StatelessWidget {
  final Channel channel;
  final double width;
  final void Function()? onTap;

  final double padding = 10.0;

  const ChannelWidget({Key? key, required this.channel, required this.width, this.onTap}) : super(key: key);

  double get imageRadius => width / 6;
  double get height => 2 * (imageRadius + padding);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        width: width,
        height: height,
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(channel.thumbnails.last.url.toString()),
              radius: imageRadius,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        channel.author,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "${channel.subCount} ${ngettext("subscriber", "subscribers", channel.subCount)}",
                        style: const TextStyle(fontSize: 14),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniWidget extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final String subtitle;
  final double width;
  final void Function()? onTap;
  final double padding = 10.0;

  const _MiniWidget({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.width,
    required this.onTap,
  }) : super(key: key);

  double get imageWidth => width / 3;
  double get imageHeight => _imageHeight(imageWidth);
  double get height => imageHeight + 2 * padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        width: width,
        height: height,
        child: Row(
          children: [
            _ThumbnailWidget(thumbnailUrl, width: imageWidth),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniVideoWidget extends StatelessWidget {
  final Video video;
  final double width;
  final void Function()? onTap;

  const MiniVideoWidget({Key? key, required this.video, required this.width, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _MiniWidget(
      title: video.title,
      subtitle: video.channel.author,
      thumbnailUrl: video.thumbnailUri.toString(),
      width: width,
      onTap: onTap,
    );
  }
}

class MiniPlaylistWidget extends StatelessWidget {
  final Playlist playlist;
  final double width;
  final void Function()? onTap;

  const MiniPlaylistWidget({Key? key, required this.playlist, required this.width, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _MiniWidget(
      title: playlist.title,
      subtitle: "${playlist.channel.author} • ${playlist.videos.length} ${ngettext("video", "videos", playlist.videos.length)}",
      thumbnailUrl: playlist.thumbnailUri?.toString(),
      width: width,
      onTap: onTap,
    );
  }
}
