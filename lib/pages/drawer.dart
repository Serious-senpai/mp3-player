import "package:flutter/material.dart";

import "../core/client.dart";
import "../core/utils.dart";

Drawer createPersistenDrawer({required BuildContext context, required Client client}) {
  var currentRoute = ModalRoute.of(context)?.settings.name;
  var currentTrack = client.playingInfo.track;
  return Drawer(
    child: Stack(
      children: [
        ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                image: (currentTrack != null && currentTrack.thumbnail != null)
                    ? DecorationImage(
                        image: MemoryImage(currentTrack.thumbnail!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: const Text("MP3 Player"),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_outlined),
              title: Text("Playlists", style: currentRoute == "/playlists" ? const TextStyle(color: Colors.green) : null),
              onTap: () => currentRoute == "/playlists" ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, "/playlists"),
            ),
            ListTile(
              leading: const Icon(Icons.equalizer_outlined),
              title: Text("Playing", style: currentRoute == "/current" ? const TextStyle(color: Colors.green) : null),
              onTap: () => currentRoute == "/current" ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, "/current"),
            ),
          ],
        ),
        Positioned(
          bottom: 5.0,
          left: 5.0,
          child: IconButton(
            iconSize: 15,
            onPressed: () => launch(Uri.https("github.com", "Serious-senpai/mp3-player")),
            icon: Image.asset("assets/github-mark-white.png"),
          ),
        )
      ],
    ),
  );
}
