import "package:flutter/material.dart";

import "core/client.dart";
import "pages/current.dart";
import "pages/playlists.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var client = await Client.create();
  runApp(MainApp(client: client));
}

class MainApp extends StatelessWidget {
  final Client client;

  const MainApp({Key? key, required this.client}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MP3 Player",
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      themeMode: ThemeMode.dark,
      initialRoute: "/playlists",
      routes: {
        "/current": (context) => CurrentPage(client: client),
        "/playlists": (context) => PlaylistPage(client: client),
      },
    );
  }
}
