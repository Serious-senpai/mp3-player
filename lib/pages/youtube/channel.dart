import "package:flutter/material.dart";

import "../drawer.dart";
import "../../src/state.dart";
import "../../src/utils.dart";
import "../../src/youtube/channels.dart";
import "../../src/youtube/playlists.dart";
import "../../src/youtube/videos.dart";
import "../../src/youtube/widgets.dart";

class YouTubeChannelPage extends StatefulWidget {
  final ApplicationState state;

  const YouTubeChannelPage({required this.state, super.key});

  @override
  State<YouTubeChannelPage> createState() => _YouTubeChannelPageState();
}

class _YouTubeChannelPageState extends State<YouTubeChannelPage> with PageStateWithDrawer<YouTubeChannelPage> {
  ApplicationState get state => widget.state;

  Channel? channel;

  @override
  WillPopBehavior get willPopBehavior => WillPopBehavior.POP_ROUTE;

  Future<List<Playlist>>? _fetchPlaylists;
  Future<List<Playlist>> get fetchPlaylists => _fetchPlaylists ??= _fetchPlaylistsImpl();
  Future<List<Playlist>> _fetchPlaylistsImpl() async {
    var channelLocal = channel;
    if (channelLocal != null) return await channelLocal.fetchPlaylists();

    return <Playlist>[];
  }

  Future<List<Video>>? _fetchVideos;
  Future<List<Video>> get fetchVideos => _fetchVideos ??= _fetchVideosImpl();
  Future<List<Video>> _fetchVideosImpl() async {
    var channelLocal = channel;
    if (channelLocal != null) return await channelLocal.fetchVideos();

    return <Video>[];
  }

  Widget videoFetchingFailure() => GestureDetector(
        onTap: () => setState(() => _fetchVideos = null),
        child: const Center(child: Text("Failed to fetch videos. Click to refresh.")),
      );

  Widget playlistsFetchingFailure() => GestureDetector(
        onTap: () => setState(() => _fetchPlaylists = null),
        child: const Center(child: Text("Failed to fetch playlists. Click to refresh.")),
      );

  @override
  Scaffold buildScaffold(BuildContext context) {
    var channelLocal = channel = ModalRoute.of(context)?.settings.arguments as Channel;
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: openDrawer,
          icon: const Icon(Icons.queue_music_outlined),
        ),
        title: Text(channelLocal.author),
      ),
      drawer: createDrawer(context: context, state: state),
      body: DefaultTabController(
        length: 3,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          width: screenSize.width,
          height: screenSize.height,
          child: Column(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(channelLocal.thumbnails.last.url.toString()),
                radius: screenSize.width / 8,
              ),
              Text(channelLocal.author, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                "${channelLocal.subCount} ${ngettext("subscriber", "subscribers", channelLocal.subCount)}",
                style: const TextStyle(fontSize: 12),
              ),
              const TabBar(
                tabs: [
                  Tab(text: "Description"),
                  Tab(text: "Videos"),
                  Tab(text: "Playlists"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Text(
                      channelLocal.description,
                      textAlign: TextAlign.left,
                    ),
                    FutureBuilder(
                      future: fetchVideos,
                      builder: (context, snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:
                            return Center(child: loadingIndicator());

                          case ConnectionState.done:
                            var videos = snapshot.data;
                            if (videos == null) {
                              return videoFetchingFailure();
                            }

                            return ListView.builder(
                              itemBuilder: (context, index) {
                                var video = videos[index];
                                return MiniVideoWidget(
                                  video: video,
                                  width: screenSize.width,
                                  onTap: () => tapToDownloadVideo(context, video),
                                );
                              },
                              itemCount: videos.length,
                            );

                          default:
                            return videoFetchingFailure();
                        }
                      },
                    ),
                    FutureBuilder(
                      future: fetchPlaylists,
                      builder: (context, snapshot) {
                        switch (snapshot.connectionState) {
                          case ConnectionState.waiting:
                            return Center(child: loadingIndicator());

                          case ConnectionState.done:
                            var playlists = snapshot.data;
                            if (playlists == null) {
                              return playlistsFetchingFailure();
                            }

                            return ListView.builder(
                              itemBuilder: (context, index) {
                                var playlist = playlists[index];
                                return MiniPlaylistWidget(
                                  playlist: playlist,
                                  width: screenSize.width,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    "/youtube/playlist",
                                    arguments: playlist,
                                  ),
                                );
                              },
                              itemCount: playlists.length,
                            );

                          default:
                            return playlistsFetchingFailure();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
