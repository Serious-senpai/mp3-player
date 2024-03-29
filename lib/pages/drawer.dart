import "package:flutter/material.dart";
import "package:meta/meta.dart";

import "../src/state.dart";
import "../src/utils.dart";

enum WillPopBehavior {
  OPEN_DRAWER,
  POP_ROUTE,
}

/// Mixin on a [State] of a [StatefulWidget] that allows opening and closing a
/// drawer in a [Scaffold]
///
/// The [buildScaffold] method should return a [Scaffold] with its [Scaffold.key]
/// set to [scaffoldKey]
mixin PageStateWithDrawer<T extends StatefulWidget> on State<T> {
  /// The [GlobalKey] for the [Scaffold] returned by the [build] method
  final scaffoldKey = GlobalKey<ScaffoldState>();

  WillPopBehavior get willPopBehavior => WillPopBehavior.OPEN_DRAWER;

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
    var scaffold = buildScaffold(context);
    assert(scaffold.key == scaffoldKey);
    assert(scaffold.drawer != null);
    return WillPopScope(
      child: scaffold,
      onWillPop: () async {
        switch (willPopBehavior) {
          case WillPopBehavior.OPEN_DRAWER:
            openDrawer();
            return false;

          case WillPopBehavior.POP_ROUTE:
            return true;
        }
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
              title: Text("Playing", style: currentRoute == "/playing" ? const TextStyle(color: Colors.green) : null),
              onTap: () => currentRoute == "/playing" ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, "/playing"),
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
