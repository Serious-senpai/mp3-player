import "package:flutter/material.dart";

import "../src/state.dart";
import "../src/utils.dart";

mixin PageStateWithDrawer<T extends StatefulWidget> on State<T> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  void openDrawer() {
    var state = scaffoldKey.currentState;
    if (state != null) state.openDrawer();
  }

  void closeDrawer() {
    var state = scaffoldKey.currentState;
    if (state != null) state.closeDrawer();
  }
}

Drawer createDrawer({required BuildContext context, required ApplicationState state}) {
  var currentRoute = ModalRoute.of(context)?.settings.name;
  return Drawer(
    child: Stack(
      children: [
        ListView(
          children: [
            const DrawerHeader(child: Text("MP3 Player")),
            ListTile(
              leading: const Icon(Icons.queue_music_outlined),
              title: Text("Playlists", style: currentRoute == "/playlists" ? const TextStyle(color: Colors.green) : null),
              onTap: () => currentRoute == "/playlists" ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, "/playlists"),
            ),
            ListTile(
              leading: const Icon(Icons.equalizer_outlined),
              title: Text("Playing", style: currentRoute == "/play" ? const TextStyle(color: Colors.green) : null),
              onTap: () => currentRoute == "/play" ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, "/play"),
            ),
          ],
        ),
        Positioned(
          bottom: 5.0,
          left: 5.0,
          child: IconButton(
            iconSize: 15,
            onPressed: () => launchUri("https://github.com/Serious-senpai/mp3-player"),
            icon: Image.asset("assets/github-mark-white.png"),
          ),
        )
      ],
    ),
  );
}
