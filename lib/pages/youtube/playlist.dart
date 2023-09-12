import "package:flutter/material.dart";

import "../drawer.dart";
import "../../src/state.dart";
import "../../src/utils.dart";
import "../../src/youtube/playlists.dart";
import "../../src/youtube/videos.dart";
import "../../src/youtube/widgets.dart";

class YouTubePlaylistPage extends StatefulWidget {
  final ApplicationState state;

  const YouTubePlaylistPage({required this.state, super.key});

  @override
  State<YouTubePlaylistPage> createState() => _YouTubePlaylistPageState();
}

class _YouTubePlaylistPageState extends State<YouTubePlaylistPage> with PageStateWithDrawer<YouTubePlaylistPage> {
  ApplicationState get state => widget.state;

  Playlist? playlist;

  @override
  WillPopBehavior get willPopBehavior => WillPopBehavior.POP_ROUTE;

  Future<Playlist?>? _fetchPlaylist;
  Future<Playlist?> get fetchPlaylist => _fetchPlaylist ??= _fetchPlaylistImpl();
  Future<Playlist?> _fetchPlaylistImpl() async {
    var playlistLocal = playlist;
    if (playlistLocal != null) {
      var error = false;
      for (var i = 0; i < playlistLocal.videos.length; i++) {
        var video = await playlistLocal.videos[i].toVideo();
        if (video == null) {
          error = true;
        } else {
          playlistLocal.videos[i] = video;
        }
      }

      if (error) {
        await showToast("Some videos couldn't be loaded");
      }
    }

    return playlistLocal;
  }

  @override
  Scaffold buildScaffold(BuildContext context) {
    playlist = ModalRoute.of(context)?.settings.arguments as Playlist;
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: openDrawer,
          icon: const Icon(Icons.queue_music_outlined),
        ),
        title: FutureBuilder(
          future: fetchPlaylist,
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return const Text("Loading...");

              case ConnectionState.done:
                var data = snapshot.data;
                return data == null ? const Text("Unavailable") : Text(data.title, overflow: TextOverflow.ellipsis);

              default:
                return const Text("Error!");
            }
          },
        ),
      ),
      drawer: createDrawer(context: context, state: state),
      body: FutureBuilder(
        future: fetchPlaylist,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: loadingIndicator(content: "Loading playlist"));

            case ConnectionState.done:
              var data = snapshot.data;
              if (data == null) return const Center(child: Text("Playlist not found"));

              return Column(
                children: [
                  PlaylistWidget(playlist: data, width: screenSize.width),
                  Expanded(
                    child: ListView.builder(
                      itemBuilder: (context, index) {
                        try {
                          var video = data.videos[index] as Video;
                          return MiniVideoWidget(
                            video: video,
                            width: screenSize.width,
                          );
                        } on Object {
                          var partialVideo = data.videos[index];
                          return ListTile(
                            leading: const Icon(Icons.error_outline),
                            title: Text(partialVideo.title),
                          );
                        }
                      },
                      itemCount: data.videos.length,
                    ),
                  ),
                ],
              );

            default:
              return Center(child: Text("Unknown state: ${snapshot.connectionState}"));
          }
        },
      ),
    );
  }
}
