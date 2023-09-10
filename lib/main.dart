import "package:flutter/material.dart";

import "pages/playing.dart";
import "pages/playlists.dart";
import "src/state.dart";
import "pages/youtube/main.dart";
import "pages/youtube/playlist.dart";

/// Application entry point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var state = await ApplicationState.create();
  runApp(MP3Player(state: state));
}

/// The main [StatelessWidget] of the application
class MP3Player extends StatelessWidget {
  /// The global [ApplicationState]
  final ApplicationState state;

  /// Construct a new [MP3Player]
  const MP3Player({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MP3 Player",
      darkTheme: ThemeData(
        appBarTheme: const AppBarTheme(backgroundColor: Colors.green, elevation: 1.0, titleTextStyle: TextStyle(color: Colors.white)),
        brightness: Brightness.dark,
        dialogTheme: DialogTheme(
          elevation: 2.0,
          iconColor: Colors.green,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.green, width: 0.5, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(5.0),
          ),
        ),
        primaryColor: Colors.black,
        primarySwatch: Colors.green,
      ),
      themeMode: ThemeMode.dark,
      initialRoute: "/playlists",
      routes: {
        "/playlists": (context) => PlaylistsPage(state: state),
        "/play": (context) => PlayPage(state: state),
        "/youtube": (context) => YouTubePage(state: state),
        "/youtube/playlist": (context) => YouTubePlaylistPage(state: state),
      },
    );
  }
}
