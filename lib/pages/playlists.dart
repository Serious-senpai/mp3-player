import "dart:io";

import "package:async_locks/async_locks.dart";
import "package:external_path/external_path.dart";
import "package:filesystem_picker/filesystem_picker.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:fluttertoast/fluttertoast.dart";
import "package:permission_handler/permission_handler.dart";

import "drawer.dart";
import "../core/client.dart";
import "../core/errors.dart";
import "../core/playlists.dart";
import "../core/tracks.dart";
import "../core/utils.dart";

const _defaultPlaylistColor = Colors.white;

enum TrackOption {
  delete,
  editTitle,
  addToPlaylist,
}

class PlaylistPage extends StatefulWidget {
  final MP3Client client;

  const PlaylistPage({required this.client, Key? key}) : super(key: key);

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> with PageStateWithDrawer<PlaylistPage> {
  MP3Client get client => widget.client;

  final _searchingString = ValueNotifier<String?>(null);
  bool get _isSearching => _searchingString.value is String;
  set _isSearching(bool value) {
    if (value) {
      _searchingString.value ??= "";
    } else {
      _searchingString.value = null;
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  ListTile addNewTrackButton(PlaylistData playlist) => ListTile(
        leading: const Icon(Icons.add_outlined),
        title: const Text("Add a new track(s)"),
        onTap: () async {
          var directories = await ExternalPath.getExternalStorageDirectories();

          if (!mounted) return;

          var target = await showDialog<Directory>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.add_outlined),
              title: const Text("Add a new track(s)"),
              content: DropdownButtonFormField<Directory>(
                items: List<DropdownMenuItem<Directory>>.generate(
                  directories.length,
                  (index) => DropdownMenuItem<Directory>(
                    value: Directory(directories[index]),
                    child: Text(directories[index]),
                  ),
                ),
                hint: const Text("Choose a location"),
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

          if (target == null || !mounted) return;

          var pickedPath = await FilesystemPicker.open(
            context: context,
            rootDirectory: target,
            title: "Choose a folder or an audio file",
            requestPermission: () async {
              var status = await Permission.manageExternalStorage.request();
              return status.isGranted;
            },
            itemFilter: (entity, path, name) => entity is Directory || (entity is File && name.endsWith(".mp3")),
          );

          if (pickedPath == null) return;

          switch (await FileSystemEntity.type(pickedPath)) {
            case (FileSystemEntityType.directory):
              var directory = Directory(pickedPath);
              var tracks = <Track>[];

              await Fluttertoast.showToast(msg: "Importing files...");

              Future<void> addEntity(FileSystemEntity entity) async {
                if (entity is File) {
                  var track = await client.createTrack(entity.path);
                  if (track != null) tracks.add(track);
                }
              }

              var futures = <Future>[];
              var completer = Event();
              directory.list(recursive: true, followLinks: false).listen(
                    (entity) => futures.add(addEntity(entity)),
                    onDone: completer.set,
                  );

              await completer.wait();
              await Future.wait(futures);

              await playlist.addAll(tracks);
              await Fluttertoast.showToast(msg: "Added ${tracks.length} track(s) to playlist");
              break;

            case (FileSystemEntityType.file):
              var track = await client.createTrack(pickedPath);
              if (track == null) return;

              await playlist.add(track);
              await Fluttertoast.showToast(msg: "Added a track to playlist");
              break;

            default:
              throw LogicalFlowException(addNewTrackButton);
          }

          refresh();
        },
      );

  ListTile editPlaylistNameButton(PlaylistData playlist) => ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: const Text("Rename playlist"),
        onTap: () async {
          var controller = TextEditingController(text: playlist.name);
          var name = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.playlist_add),
              title: const Text("Rename playlist"),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration.collapsed(hintText: "Playlist name"),
                keyboardType: TextInputType.text,
                showCursor: true,
                enableSuggestions: false,
                maxLength: 50,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text("OK"),
                ),
              ],
            ),
          );

          if (name == null) return;

          if (name.isNotEmpty) {
            await playlist.rename(name);
            await Fluttertoast.showToast(msg: "Renamed playlist");
            refresh();
          } else {
            await Fluttertoast.showToast(msg: "Playlist name cannot be empty!");
          }
        },
      );

  ListTile clearPlaylistButton(PlaylistData playlist) => ListTile(
        leading: const Icon(Icons.delete),
        title: const Text("Clear playlist"),
        onTap: () async {
          if (playlist.playing) {
            await Fluttertoast.showToast(msg: "Cannot remove playing playlist");
            return;
          }

          var option = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  icon: const Icon(Icons.playlist_remove),
                  title: const Text("Clear this playlist?"),
                  actions: <TextButton>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("NO"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("YES"),
                    ),
                  ],
                ),
              ) ??
              false;

          if (option) {
            await playlist.clear();
            await Fluttertoast.showToast(msg: "Cleared playlist");
            refresh();
          }
        },
      );

  ListTile removePlaylistButton(PlaylistData playlist) => ListTile(
        leading: const Icon(Icons.delete),
        title: const Text("Remove playlist"),
        onTap: () async {
          if (playlist.playing) {
            await Fluttertoast.showToast(msg: "Cannot remove playing playlist");
            return;
          }

          var option = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  icon: const Icon(Icons.playlist_remove),
                  title: const Text("Remove this playlist?"),
                  actions: <TextButton>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("NO"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("YES"),
                    ),
                  ],
                ),
              ) ??
              false;

          if (option) {
            await playlist.removePlaylist();
            await Fluttertoast.showToast(msg: "Removed playlist");
            refresh();
          }
        },
      );

  Widget trackTile(PlaylistData playlist, int index) {
    var track = playlist.tracks[index];
    if (_isSearching && !track.title.toLowerCase().contains(_searchingString.value!.toLowerCase())) {
      return const SizedBox.shrink();
    }

    var isPlayingTrack = playlist.playing && (client.playingInfo.index == index);

    Widget? trailing;
    if (isPlayingTrack) {
      trailing = StreamBuilder(
        stream: client.playingInfo.realtimePlayingInfos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            throw snapshot.error!;
          }

          var data = snapshot.data;
          return (data == null || !data.isPlaying)
              ? TextButton(
                  onPressed: () => client.resume(),
                  child: const Icon(
                    Icons.play_arrow_outlined,
                    color: defaultIconColor,
                  ),
                )
              : TextButton(
                  onPressed: () => client.pause(),
                  child: const Icon(
                    Icons.pause,
                    color: defaultIconColor,
                  ),
                );
        },
      );
    }

    var textStyle = isPlayingTrack ? const TextStyle(color: Colors.green) : null;
    return ListTile(
      leading: track.displayThumbnail(),
      title: Text(track.title, style: textStyle),
      subtitle: track.artist == null ? null : Text(track.artist!, style: textStyle),
      trailing: trailing,
      onTap: () async {
        Navigator.pushReplacementNamed(context, "/current");
        if (!isPlayingTrack) await client.play(playlist: playlist, index: index);
      },
      onLongPress: () async {
        var option = await showDialog<TrackOption>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text("Track options"),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, TrackOption.delete),
                child: const Text("Delete"),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, TrackOption.editTitle),
                child: const Text("Edit title"),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, TrackOption.addToPlaylist),
                child: const Text("Add to playlist"),
              ),
            ],
          ),
        );

        switch (option) {
          case TrackOption.delete:
            if ((client.playingInfo.playlist == playlist) && (client.playingInfo.index == index)) {
              await Fluttertoast.showToast(msg: "Cannot remove playing track");
            } else {
              await playlist.remove(index);
              await Fluttertoast.showToast(msg: "Removed ${track.title}");
              refresh();
            }
            return;

          case TrackOption.editTitle:
            if (!mounted) return;

            var controller = TextEditingController(text: track.title);
            var newTitle = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Edit title"),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration.collapsed(hintText: "New title"),
                  keyboardType: TextInputType.text,
                  showCursor: true,
                  enableSuggestions: false,
                  maxLength: 50,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text("OK"),
                  ),
                ],
              ),
            );

            if (newTitle != null) {
              var status = await track.editTitle(newTitle);

              if (status) {
                await Fluttertoast.showToast(msg: "Set track title to \"$newTitle\"");
                refresh();
              } else {
                await Fluttertoast.showToast(msg: "Unable to change track title");
              }
            }

            return;

          case TrackOption.addToPlaylist:
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
            await target.add(track);
            await Fluttertoast.showToast(msg: "Added track to \"${target.name}\"");
            refresh();

            return;

          default:
            return;
        }
      },
    );
  }

  Widget playlistsDisplayBuilder(BuildContext context, AsyncSnapshot<void> snapshot) {
    if (snapshot.hasError) {
      throw snapshot.error!;
    }

    var playlists = List<PlaylistData>.from(client.allPlaylists);
    playlists.sort((first, second) => first.name.compareTo(second.name));

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

    return Column(
      children: [
        Flexible(
          child: ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, playlistIndex) {
              var playlist = playlists[playlistIndex];
              return ExpansionTile(
                title: Text(
                  "(${playlist.length}) ${playlist.name}",
                  style: TextStyle(color: playlist.playing ? Colors.green : _defaultPlaylistColor),
                ),
                subtitle: Text(
                  playlist.displayArtists,
                  style: TextStyle(color: playlist.playing ? Colors.green : _defaultPlaylistColor),
                ),
                initiallyExpanded: _isSearching,
                children: List<Widget>.generate(
                  playlist.tracks.length + 4,
                  (index) {
                    switch (index) {
                      case 0:
                        return addNewTrackButton(playlist);

                      case 1:
                        return editPlaylistNameButton(playlist);

                      case 2:
                        return clearPlaylistButton(playlist);

                      case 3:
                        return removePlaylistButton(playlist);

                      default:
                        return trackTile(playlists[playlistIndex], index - 4);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    client.playingInfo.state.removeListener(refresh);
    _searchingString.removeListener(refresh);
    super.dispose();
  }

  @override
  void initState() {
    client.playingInfo.state.addListener(refresh);
    _searchingString.addListener(refresh);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var scaffold = Scaffold(
      key: scaffoldKey,
      appBar: _isSearching
          ? AppBar(
              leading: TextButton(
                onPressed: () => openDrawer(),
                child: const Icon(Icons.queue_music_outlined),
              ),
              title: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "Search track title"),
                  keyboardType: TextInputType.text,
                  showCursor: true,
                  autofocus: _searchingString.value!.isEmpty,
                  enableSuggestions: false,
                  onChanged: (value) {
                    _searchingString.value = value;
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    _isSearching = false;
                    refresh();
                  },
                  child: const Icon(Icons.search_off_outlined),
                ),
                seperator,
              ],
            )
          : AppBar(
              leading: TextButton(
                onPressed: () => openDrawer(),
                child: const Icon(Icons.queue_music_outlined),
              ),
              title: const Text("Playlists"),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    var controller = TextEditingController();
                    var name = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        icon: const Icon(Icons.playlist_add),
                        title: const Text("Create a new playlist"),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration.collapsed(hintText: "Playlist name"),
                          keyboardType: TextInputType.text,
                          showCursor: true,
                          enableSuggestions: false,
                          maxLength: 50,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, controller.text),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );

                    if (name == null) return;

                    if (name.isNotEmpty) {
                      await client.createPlaylist(name);
                      await Fluttertoast.showToast(msg: "Created a new playlist!");
                      refresh();
                    } else {
                      await Fluttertoast.showToast(msg: "Playlist name cannot be empty!");
                    }
                  },
                  child: const Icon(Icons.playlist_add),
                ),
                seperator,
                TextButton(
                  onPressed: () {
                    _isSearching = true;
                    refresh();
                  },
                  child: const Icon(Icons.search_outlined),
                ),
                seperator,
              ],
            ),
      drawer: createPersistenDrawer(context: context, client: client),
      body: StreamBuilder(
        stream: playlistsUpdateSignal(),
        builder: playlistsDisplayBuilder,
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, "/current");
        return false;
      },
      child: scaffold,
    );
  }
}
