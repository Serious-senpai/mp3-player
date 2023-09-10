import "dart:io";

import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:permission_handler/permission_handler.dart";

import "channels.dart";
import "playlists.dart";
import "videos.dart";
import "../downloader.dart";
import "../utils.dart";

Widget _renderThumbnailImage(String src, {required double width}) => Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(src),
          fit: BoxFit.fitWidth,
          alignment: const Alignment(-1.0, 0.0),
        ),
      ),
      width: width,
      height: 9 * width / 16,
    );

Widget _renderChannelImage(BuildContext context, AsyncSnapshot<Channel?> snapshot) {
  switch (snapshot.connectionState) {
    case ConnectionState.waiting:
      return loadingIndicator(size: 18);
    case ConnectionState.done:
      var data = snapshot.data;
      return data == null
          ? const Icon(Icons.error_outline, size: 18)
          : CircleAvatar(
              backgroundImage: NetworkImage(data.thumbnails[0].url.toString()),
              radius: 18,
            );

    default:
      return const Icon(Icons.error_outline, size: 18);
  }
}

Future<void> tapToDownload(BuildContext context, Video video) async {
  var urlFuture = video.getAudioUrl();
  var directories = await getExternalFilesDirs() ?? [];

  if (context.mounted) {
    var rootDirectory = await showDialog<Directory>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select download location"),
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
          hint: const Text("Select a directory"),
          isExpanded: true,
          onChanged: (value) => Navigator.pop(context, value),
        ),
      ),
    );

    if (context.mounted) {
      if (rootDirectory == null) return;
      var pickedPath = await FilesystemPicker.openDialog(
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

      if (pickedPath == null) return;

      if (context.mounted) {
        var fileName = "${removeReservedCharacters(video.title)}.mp3";
        var url = await urlFuture;
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
    }
  }
}

class VideoWidget extends StatelessWidget {
  final Video video;
  final double width;
  final void Function()? onTap;

  final Future<Channel?> _getChannelFuture;

  VideoWidget({Key? key, required this.video, required this.width, this.onTap})
      : _getChannelFuture = video.channel.toChannel(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _renderThumbnailImage(video.thumbnailUri.toString(), width: width),
            Row(
              children: [
                FutureBuilder(
                  future: _getChannelFuture,
                  builder: _renderChannelImage,
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
  final double width;
  final void Function()? onTap;

  final Future<Channel?> _getChannelFuture;

  PlaylistWidget({Key? key, required this.playlist, required this.width, this.onTap})
      : _getChannelFuture = playlist.channel.toChannel(),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _renderThumbnailImage(playlist.thumbnailUri.toString(), width: width),
            Row(
              children: [
                FutureBuilder(
                  future: _getChannelFuture,
                  builder: _renderChannelImage,
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
                          "${playlist.channel} • ${playlist.videos.length} videos",
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
