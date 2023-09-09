import "package:flutter/material.dart";

import "playlists.dart";
import "videos.dart";

Image _networkImage(String src, {required double width}) => Image.network(
      src,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined),
      width: width,
      fit: BoxFit.fitWidth,
    );

class VideoWidget extends StatelessWidget {
  final Video video;
  final double width;

  const VideoWidget({Key? key, required this.video, required this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkImage(video.thumbnailUri.toString(), width: width),
          Text(
            video.title,
            softWrap: true,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            video.author,
            softWrap: true,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PlaylistWidget extends StatelessWidget {
  final Playlist playlist;
  final double width;

  const PlaylistWidget({Key? key, required this.playlist, required this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10.0),
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _networkImage(playlist.thumbnailUri.toString(), width: width),
          Padding(
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
                  "${playlist.author} • ${playlist.videos.length} videos",
                  softWrap: true,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
