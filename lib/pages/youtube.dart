import "dart:io";

import "package:flutter/material.dart";
import "package:fluttertoast/fluttertoast.dart";

import "drawer.dart";
import "../core/client.dart";
import "../core/playlists.dart";
import "../core/tracks.dart";
import "../core/utils.dart";

class YouTubePage extends StatefulWidget {
  final MP3Client client;

  const YouTubePage({required this.client, Key? key}) : super(key: key);

  @override
  State<YouTubePage> createState() => _YouTubePageState();
}

class _YouTubePageState extends State<YouTubePage> with PageStateWithDrawer<YouTubePage> {
  MP3Client get client => widget.client;

  final searchController = TextEditingController();

  Future<List<YouTubeTrack>>? searchFuture;

  void refresh() {
    if (mounted) setState(() {});
  }

  Widget constructPage(BuildContext context) {
    var children = <Widget>[
      TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: "Search YouTube video",
          suffixIcon: IconButton(
            onPressed: () => searchController.clear(),
            icon: const Icon(Icons.clear),
          ),
        ),
        keyboardType: TextInputType.text,
        showCursor: true,
        autofocus: false,
        onSubmitted: (text) {
          if (text.isNotEmpty) {
            searchFuture = client.ytClient?.search(text);
          }
          refresh();
        },
      ),
      seperator,
      seperator,
    ];

    if (searchFuture != null) {
      children.add(
        FutureBuilder(
          future: searchFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              throw snapshot.error!;
            }

            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return Center(child: loadingIndicator(content: "Searching"));

              case ConnectionState.done:
                var results = snapshot.data!;
                return Flexible(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      var item = results[index];
                      return ListTile(
                        leading: Image.network(item.thumbnailUrl.toString(), fit: BoxFit.cover),
                        title: Text(item.title),
                        subtitle: Text(item.artist!), // We always know a YouTube video's author (i.e. channel)
                        trailing: TextButton(
                          onPressed: () async {
                            var playlists = await client.fetchPlaylists();

                            if (!mounted) return;

                            var target = await showDialog<PlaylistData>(
                              context: context,
                              builder: (context) => AlertDialog(
                                icon: const Icon(Icons.add_outlined),
                                title: const Text("Add to playlist"),
                                content: DropdownButtonFormField<PlaylistData>(
                                  items: List<DropdownMenuItem<PlaylistData>>.generate(
                                    playlists.length,
                                    (index) => DropdownMenuItem(
                                      value: playlists[index],
                                      child: Text(playlists[index].name),
                                    ),
                                  ),
                                  hint: const Text("Choose a playlist"),
                                  onChanged: (value) => Navigator.pop(context, value),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                ],
                              ),
                            );

                            if (target == null) return;
                            await target.add(item);
                            await Fluttertoast.showToast(msg: "Added track to \"${target.name}\"");
                            refresh();
                          },
                          child: const Icon(Icons.playlist_add_outlined),
                        ),
                      );
                    },
                  ),
                );

              default:
                return const SizedBox.shrink();
            }
          },
        ),
      );
    }

    return Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    var scaffold = Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => openDrawer(),
          child: const Icon(Icons.search_outlined),
        ),
        title: const Text("YouTube"),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await client.initializeYtClient();
                await Fluttertoast.showToast(msg: "Optimizing YouTube client...");
                await client.ytClient!.sortInstances();
                await Fluttertoast.showToast(msg: "YouTube client optimized!");
              } on SocketException {
                // pass
              }
            },
            child: const Icon(Icons.build_outlined),
          ),
        ],
      ),
      drawer: createPersistenDrawer(context: context, client: client),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: constructPage(context),
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