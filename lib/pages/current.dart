import "package:assets_audio_player/assets_audio_player.dart";
import "package:audio_video_progress_bar/audio_video_progress_bar.dart";
import "package:flutter/material.dart";

import "drawer.dart";
import "../core/client.dart";
import "../core/errors.dart";
import "../core/utils.dart";

class CurrentPage extends StatefulWidget {
  final Client client;

  const CurrentPage({required this.client, Key? key}) : super(key: key);

  @override
  State<CurrentPage> createState() => _CurrentPageState();
}

class _CurrentPageState extends State<CurrentPage> {
  Client get client => widget.client;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void openDrawer() {
    var state = _scaffoldKey.currentState;
    if (state != null) {
      state.openDrawer();
    }
  }

  void closeDrawer() {
    var state = _scaffoldKey.currentState;
    if (state != null) {
      state.closeDrawer();
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Widget constructPage(BuildContext context, AsyncSnapshot<RealtimePlayingInfos> snapshot) {
    if (snapshot.hasError) {
      throw OperationException(constructPage, snapshot.error);
    }

    var data = snapshot.data;
    if (data != null) {
      var playing = data.current;
      if (playing != null) {
        var track = client.playingInfo.track!;
        var screenSize = MediaQuery.of(context).size;
        return Column(
          children: [
            track.displayThumbnail(size: screenSize.shortestSide / 3),
            seperator,
            Center(child: Text(track.title, style: const TextStyle(fontSize: 22))),
            seperator,
            Align(alignment: Alignment.centerRight, child: Text(track.artist ?? "Unknown artist", style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic))),
            seperator,
            Align(alignment: Alignment.centerRight, child: Text(track.album ?? "Unknown album", style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic))),
            seperator,
            ProgressBar(
              progress: data.currentPosition,
              total: playing.audio.duration,
              onSeek: (value) => client.seek(value),
            ),
            seperator,
            Center(
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => client.stop(),
                      child: const Icon(
                        Icons.stop,
                        color: defaultIconColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => client.previous(),
                      child: const Icon(
                        Icons.skip_previous_outlined,
                        color: defaultIconColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: data.isPlaying
                        ? FloatingActionButton(
                            onPressed: () => client.pause(),
                            child: const Icon(
                              Icons.pause,
                              color: defaultIconColor,
                            ),
                          )
                        : FloatingActionButton(
                            onPressed: () => client.resume(),
                            child: const Icon(
                              Icons.play_arrow_outlined,
                              color: defaultIconColor,
                            ),
                          ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => client.next(),
                      child: const Icon(
                        Icons.skip_next_outlined,
                        color: defaultIconColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => client.toggleRepeat(),
                      child: Icon(
                        Icons.loop_outlined,
                        color: client.playingInfo.repeatOne ? Colors.green : defaultIconColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => client.toggleShuffle(),
                      child: Icon(
                        Icons.shuffle_outlined,
                        color: client.playingInfo.shuffle ? Colors.green : defaultIconColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    }

    return const Center(child: Text("No playing audio"));
  }

  @override
  Widget build(BuildContext context) {
    var scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => openDrawer(),
          child: const Icon(Icons.equalizer_outlined),
        ),
        title: const Text("Playing"),
      ),
      drawer: createPersistenDrawer(context: context, client: client),
      body: StreamBuilder(
        stream: client.playingInfo.realtimePlayingInfos,
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: constructPage(context, snapshot),
        ),
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, "/playlists");
        return false;
      },
      child: scaffold,
    );
  }
}
