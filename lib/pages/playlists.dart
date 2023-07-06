import "dart:io";

import "package:async_locks/async_locks.dart";
import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:permission_handler/permission_handler.dart";

import "drawer.dart";
import "../src/playlists.dart";
import "../src/state.dart";
import "../src/tracks.dart";
import "../src/utils.dart";

/// Actions to perform on a track
enum TrackOption {
  /// Share a track via the system's interface
  SHARE,

  /// Remove a track from the playlist
  REMOVE,
}

/// The initial route of the application that displays all created [Playlist]s
class PlaylistsPage extends StatefulWidget {
  /// The global [ApplicationState]
  final ApplicationState state;

  /// Construct a new [PlaylistsPage]
  const PlaylistsPage({required this.state, super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> with PageStateWithDrawer<PlaylistsPage> {
  ApplicationState get state => widget.state;

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Playlist.fetchAll(state: state);
    var scaffold = Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: openDrawer,
          icon: const Icon(Icons.queue_music_outlined),
        ),
        title: const Text("Playlists"),
        actions: [
          IconButton(
            onPressed: () async {
              var controller = TextEditingController();
              var title = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Create a new playlist"),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration.collapsed(hintText: "Playlist title"),
                    keyboardType: TextInputType.text,
                    showCursor: true,
                    autofocus: true,
                    enableSuggestions: false,
                    maxLength: 50,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    onSubmitted: (value) => Navigator.pop(context, value),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );

              if (title != null) {
                if (title.isNotEmpty) {
                  await Playlist.create(title, state: state);

                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Created a new playlist!")));
                } else {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist title cannot be empty!")));
                }
              }
            },
            icon: const Icon(Icons.playlist_add_outlined),
          ),
        ],
      ),
      drawer: createDrawer(context: context, state: state),
      body: StreamBuilder(
        stream: Playlist.fetchingState.stream,
        builder: (context, snapshot) {
          var playlistsDisplay = StreamBuilder(
            stream: Playlist.playlists.stream,
            builder: (context, _) {
              var playlists = List<Playlist>.from(Playlist.playlists.values);
              if (playlists.isEmpty) {
                return Center(
                  child: RichText(
                    text: const TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: "Click "),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.playlist_add),
                        ),
                        TextSpan(text: " to create a new playlist"),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(3.0),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  var playlist = playlists[index];

                  var children = <Widget>[
                    ListTile(
                      leading: const Icon(Icons.add_outlined),
                      title: const Text("Add a new track(s)"),
                      onTap: () async {
                        var directories = await getExternalFilesDirs() ?? [];

                        if (!mounted) return;
                        var rootDirectory = await showDialog<Directory>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Choose a location"),
                            content: DropdownButtonFormField<Directory>(
                              items: List<DropdownMenuItem<Directory>>.generate(
                                directories.length,
                                (index) => DropdownMenuItem<Directory>(
                                  value: directories[index],
                                  child: Text(
                                    directories[index].path,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              hint: const Text("Select a directory"),
                              isExpanded: true,
                              onChanged: (value) => Navigator.pop(context, value),
                            ),
                          ),
                        );

                        if (rootDirectory == null || !mounted) return;

                        var pickedPath = await FilesystemPicker.openDialog(
                          context: context,
                          requestPermission: () async {
                            var status = await Permission.storage.request();
                            return status.isGranted;
                          },
                          rootDirectory: rootDirectory,
                          showGoUp: true,
                          title: "Select a folder or an audio file",
                        );

                        if (pickedPath == null) return;

                        var file = File(pickedPath);
                        if (await file.exists()) {
                          var track = await Track.fromPath(pickedPath);
                          if (track != null) {
                            await playlist.add(track);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added a track to playlist!")));
                          } else {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not an audio file!")));
                          }
                        }

                        var directory = Directory(pickedPath);
                        if (await directory.exists()) {
                          var tracks = <Track>[];

                          Future<void> fromEntity(FileSystemEntity entity) async {
                            if (entity is File) {
                              var track = await Track.fromPath(entity.path);
                              if (track != null) {
                                tracks.add(track);
                              }
                            }
                          }

                          var completer = Event();
                          var futures = <Future<void>>[];
                          directory.list(recursive: true, followLinks: false).listen(
                            (entity) {
                              futures.add(fromEntity(entity));
                            },
                            onDone: completer.set,
                          );

                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Importing audio files...")));

                          await completer.wait();
                          await Future.wait(futures);
                          await playlist.addAll(tracks);

                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${tracks.length} track(s) to playlist!")));
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_note_outlined),
                      title: const Text("Rename playlist"),
                      onTap: () async {
                        var controller = TextEditingController();
                        var title = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Rename playlist"),
                            content: TextField(
                              controller: controller,
                              decoration: const InputDecoration.collapsed(hintText: "Playlist title"),
                              keyboardType: TextInputType.text,
                              showCursor: true,
                              autofocus: true,
                              enableSuggestions: false,
                              maxLength: 50,
                              maxLengthEnforcement: MaxLengthEnforcement.enforced,
                              onSubmitted: (value) => Navigator.pop(context, value),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, controller.text),
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );

                        if (title != null) {
                          if (title.isNotEmpty) {
                            await playlist.rename(title);

                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Renamed playlist!")));
                          } else {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Playlist title cannot be empty!")));
                          }
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text("Remove playlist"),
                      onTap: () async {
                        var option = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete this playlist?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Yes"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("No"),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (option) {
                          await playlist.delete();
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removed playlist")));
                        }
                      },
                    ),
                  ];

                  children.addAll(
                    Iterable<Widget>.generate(
                      playlist.items.length,
                      (index) {
                        var track = playlist.items[index];
                        var artist = track.trackInfo.artist;

                        return StreamBuilder(
                          initialData: state,
                          stream: state.streamState,
                          builder: (context, _) => ListTile(
                            leading: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 45.0, maxHeight: 45.0),
                              child: fallbackToLogo(track.trackInfo.thumbnailPath),
                            ),
                            title: Text(track.title, style: index == playlist.playingIndex ? const TextStyle(color: Colors.green) : null),
                            subtitle: artist != null ? Text(artist, style: index == playlist.playingIndex ? const TextStyle(color: Colors.green) : null) : null,
                            trailing: index == playlist.playingIndex
                                ? state.isPlaying
                                    ? IconButton(
                                        onPressed: state.pause,
                                        icon: const Icon(Icons.pause_outlined, color: Colors.green),
                                      )
                                    : IconButton(
                                        onPressed: state.resume,
                                        icon: const Icon(Icons.play_arrow_outlined, color: Colors.green),
                                      )
                                : null,
                            onTap: () async {
                              Navigator.pushReplacementNamed(context, "/play");
                              if (index != playlist.playingIndex) await state.play(playlist: playlist, index: index);
                            },
                            onLongPress: () async {
                              var option = await showDialog<TrackOption>(
                                context: context,
                                builder: (context) => SimpleDialog(
                                  title: Text(track.title, overflow: TextOverflow.ellipsis),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(context, TrackOption.SHARE),
                                      child: const Text("Share"),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(context, TrackOption.REMOVE),
                                      child: const Text("Remove from playlist"),
                                    ),
                                  ],
                                ),
                              );

                              switch (option) {
                                case TrackOption.SHARE:
                                  await shareFile(track.uri);
                                  break;

                                case TrackOption.REMOVE:
                                  await playlist.remove(index);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removed a track from playlist")));
                                  break;

                                default:
                                  break;
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );

                  return ExpansionTile(
                    leading: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 45.0, maxHeight: 45.0),
                      child: fallbackToLogo(playlist.thumbnailPath),
                    ),
                    title: Text("(${playlist.items.length}) ${playlist.title}"),
                    subtitle: Text(playlist.displayArtist),
                    children: children,
                  );
                },
              );
            },
          );

          switch (snapshot.data) {
            case PlaylistsFetchingState.FETCHING:
              return Stack(
                children: [
                  playlistsDisplay,
                  Center(child: loadingIndicator()),
                ],
              );

            default:
              return playlistsDisplay;
          }
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
