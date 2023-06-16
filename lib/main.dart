import "package:flutter/material.dart";

import "pages/play.dart";
import "pages/playlists.dart";
import "src/state.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var state = await ApplicationState.create();
  runApp(MP3Player(state: state));
}

class MP3Player extends StatelessWidget {
  final ApplicationState state;

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
      },
    );
  }
}
