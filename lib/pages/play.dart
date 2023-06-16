import "dart:math";

import "package:flutter/material.dart";
import "package:audio_video_progress_bar/audio_video_progress_bar.dart";

import "drawer.dart";
import "../src/state.dart";
import "../src/utils.dart";

class PlayPage extends StatefulWidget {
  final ApplicationState state;

  const PlayPage({required this.state, super.key});

  @override
  State<PlayPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlayPage> with PageStateWithDrawer<PlayPage> {
  ApplicationState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    var scaffold = Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: openDrawer,
          icon: const Icon(Icons.equalizer_outlined),
        ),
        title: const Text("Playing"),
      ),
      drawer: createDrawer(context: context, state: state),
      body: StreamBuilder(
        initialData: state,
        stream: state.streamState,
        builder: (context, snapshot) {
          var error = snapshot.error;
          if (error != null) throw error;

          var screenSize = MediaQuery.of(context).size;

          var state = snapshot.data!;
          var currentTrack = state.currentTrack;
          var imageSize = min(screenSize.width, screenSize.height) / 3;
          return currentTrack != null
              ? Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Column(
                    children: [
                      fallbackToLogo(
                        currentTrack.trackInfo.thumbnailPath,
                        width: imageSize,
                        height: imageSize,
                      ),
                      seperator,
                      Text(currentTrack.title),
                      seperator,
                      ProgressBar(
                        progress: Duration(milliseconds: state.currentPosition),
                        total: Duration(milliseconds: state.duration),
                        onSeek: state.seek,
                      ),
                      seperator,
                      Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              onPressed: state.previous,
                              icon: const Icon(Icons.skip_previous_outlined),
                            ),
                          ),
                          Expanded(
                            child: state.isPlaying
                                ? IconButton(
                                    onPressed: state.pause,
                                    icon: const Icon(Icons.pause_outlined),
                                  )
                                : IconButton(
                                    onPressed: state.resume,
                                    icon: const Icon(Icons.play_arrow_outlined),
                                  ),
                          ),
                          Expanded(
                            child: IconButton(
                              onPressed: state.toggleRepeat,
                              icon: Icon(
                                Icons.loop_outlined,
                                color: state.repeat ? Colors.green : null,
                              ),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              onPressed: state.stop,
                              icon: const Icon(Icons.stop_outlined),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              onPressed: state.next,
                              icon: const Icon(Icons.skip_next_outlined),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const Center(child: Text("No audio is currently playing"));
        },
      ),
    );

    return WillPopScope(
      child: scaffold,
      onWillPop: () async {
        openDrawer();
        return false;
      },
    );
  }
}
