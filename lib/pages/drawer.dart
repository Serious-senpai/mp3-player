import "package:flutter/material.dart";
import "package:meta/meta.dart";

import "../src/state.dart";
import "../src/utils.dart";

/// Mixin on a [State] of a [StatefulWidget] that allows opening and closing a
/// drawer in a [Scaffold]
///
/// The [build] method should return a [Scaffold] with its [Scaffold.key]
/// set to [scaffoldKey]
mixin PageStateWithDrawer<T extends StatefulWidget> on State<T> {
  /// The [GlobalKey] for the [Scaffold] returned by the [build] method
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Open the [Scaffold.drawer]
  void openDrawer() {
    var state = scaffoldKey.currentState;
    if (state != null) state.openDrawer();
  }

  /// Close the [Scaffold.drawer]
  void closeDrawer() {
    var state = scaffoldKey.currentState;
    if (state != null) state.closeDrawer();
  }

  Scaffold buildScaffold(BuildContext context);

  @nonVirtual
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: buildScaffold(context),
      onWillPop: () async {
        openDrawer();
        return false;
      },
    );
  }
}

/// Create a default [Drawer] for all pages within this application
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
            ListTile(
              leading: const Icon(Icons.youtube_searched_for_outlined),
              title: Text("YouTube MP3", style: currentRoute == "/youtube" ? const TextStyle(color: Colors.green) : null),
              onTap: () => currentRoute == "/youtube" ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, "/youtube"),
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
