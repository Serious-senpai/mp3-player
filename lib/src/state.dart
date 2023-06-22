import "package:async_locks/async_locks.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:sqflite/sqflite.dart";

import "playlists.dart";
import "tracks.dart";

/// The global, singleton [ApplicationState]
class ApplicationState {
  static const String UPDATE_STATE_METHOD = "com.haruka.mp3_player.UPDATE_STATE";
  static const String ON_COMPLETION_METHOD = "com.haruka.mp3_player.ON_COMPLETION";
  static const String ON_ERROR_METHOD = "com.haruka.mp3_player.ON_ERROR";
  static const String ON_INFO_METHOD = "com.haruka.mp3_player.ON_INFO";
  static const String ON_PREPARED_METHOD = "com.haruka.mp3_player.ON_PREPARED";
  static const String ON_SEEK_COMPLETE_METHOD = "com.haruka.mp3_player.ON_SEEK_COMPLETE";

  static const String INDEX_KEY = "INDEX";
  static const String CURRENT_POSITION_KEY = "CURRENT_POSITION";
  static const String DURATION_KEY = "DURATION";
  static const String IS_PLAYING_KEY = "IS_PLAYING";
  static const String PLAYLIST_ID_KEY = "PLAYLIST_ID";
  static const String REPEAT_KEY = "REPEAT";
  static const String SHUFFLE_KEY = "SHUFFLE";

  /// The application SQLite [Database]
  final Database database;
  final MethodChannel _platform;

  Playlist? _currentPlaylist;

  /// The current playing [Playlist], or `null` if not playing
  Playlist? get currentPlaylist => _currentPlaylist;

  /// The current playing [Track], or `null` if not playing
  Track? get currentTrack {
    var playlist = _currentPlaylist;
    if (playlist == null || _index < 0) return null;
    return playlist.items[_index];
  }

  int _index = -1;

  /// The current index of the playing [Track] (a.k.a. [currentTrack]) in its [Playlist] (a.k.a. [currentPlaylist])
  int get index => _index;

  /// Whether the application is currently playing any [Track]
  bool isPlaying = false;

  /// Whether the repeat mode is currently on.
  ///
  /// This should be the same as `MediaPlayer.isLooping()` on the native side.
  /// See also: https://developer.android.com/reference/android/media/MediaPlayer#isLooping()
  bool repeat = false;

  /// Whether the shuffle mode is currently on
  bool shuffle = false;

  /// The current position (in milliseconds) of [currentTrack]. This value shouldn't be rely on when no track is playing.
  ///
  /// This should be the same as `MediaPlayer.getCurrentPosition()` on the native side.
  /// See also: https://developer.android.com/reference/android/media/MediaPlayer#getCurrentPosition()
  int currentPosition = 0;

  /// The duration (a.k.a. length) in milliseconds of [currentTrack]. This value shouldn't be rely on when no track is playing.
  ///
  /// This should be the same as `MediaPlayer.getDuration()` on the native side.
  /// See also: https://developer.android.com/reference/android/media/MediaPlayer#getDuration()
  int duration = 0;
  final _streamStateEvent = Event();

  ApplicationState._({required this.database}) : _platform = const MethodChannel("com.haruka.mp3_player/player", JSONMethodCodec()) {
    _platform.setMethodCallHandler(
      (call) async {
        // print("Received $call");
        switch (call.method) {
          case UPDATE_STATE_METHOD:
            var arguments = call.arguments;

            if (arguments[PLAYLIST_ID_KEY] >= 0) {
              _currentPlaylist = await Playlist.fromId(arguments[PLAYLIST_ID_KEY], state: this);
            } else {
              _currentPlaylist = null;
            }

            _index = arguments[INDEX_KEY];
            isPlaying = arguments[IS_PLAYING_KEY];
            repeat = arguments[REPEAT_KEY];
            shuffle = arguments[SHUFFLE_KEY];
            currentPosition = arguments[CURRENT_POSITION_KEY];
            duration = arguments[DURATION_KEY];
            _streamStateEvent.set();
            break;
          case ON_COMPLETION_METHOD:
            break;
          case ON_ERROR_METHOD:
            break;
          case ON_INFO_METHOD:
            break;
          case ON_PREPARED_METHOD:
            break;
          case ON_SEEK_COMPLETE_METHOD:
            break;
          default:
            throw UnimplementedError("Unknown method ${call.method}");
        }
      },
    );
  }

  Stream<ApplicationState>? _streamState;

  /// A [Stream] that broadcasts this [ApplicationState]
  Stream<ApplicationState> get streamState => _streamState ??= _streamStateImpl().asBroadcastStream();
  Stream<ApplicationState> _streamStateImpl() async* {
    while (true) {
      yield this;
      await _streamStateEvent.wait();
      _streamStateEvent.clear();
    }
  }

  /// Send data to the native side and request that a track should be played
  Future<void> play({required Playlist playlist, required int index}) async {
    await _platform.invokeMapMethod(
      "play",
      {
        "tracks": List<Map<String, String?>>.generate(playlist.items.length, (index) => playlist.items[index].data),
        "playlistId": playlist.id,
        "index": index,
      },
    );
  }

  /// Request a pause from the native side
  Future<void> pause() => _platform.invokeMapMethod("pause");

  /// Request a resume from the native side
  Future<void> resume() => _platform.invokeMapMethod("resume");

  /// Request to the native side that the MediaPlayer should seek to the specified [duration]
  Future<void> seek(Duration duration) => _platform.invokeMapMethod("seek", {"duration": duration.inMilliseconds});

  /// Request to the native side to skip to the next track in [currentPlaylist]
  Future<void> next() => _platform.invokeMapMethod("next");

  /// Request to the native side to skip to the previous track in the [currentPlaylist]
  Future<void> previous() => _platform.invokeMapMethod("previous");

  /// Request to the native side to stop the MediaPlayer
  Future<void> stop() => _platform.invokeMapMethod("stop");

  /// Toggle the looping mode of the native MediaPlayer
  ///
  /// See also: https://developer.android.com/reference/android/media/MediaPlayer#setLooping(boolean)
  Future<void> toggleRepeat() => _platform.invokeMapMethod("toggleRepeat");

  /// Toggle the shuffle mode of the player
  Future<void> toggleShuffle() => _platform.invokeMapMethod("toggleShuffle");

  /// Update the native player's metadata
  Future<void> update({Playlist? playlist, int? index}) async {
    var data = <String, dynamic>{};
    if (playlist != null) {
      data["tracks"] = List<Map<String, String?>>.generate(playlist.items.length, (index) => playlist.items[index].data);
      data["playlistId"] = playlist.id;
    }
    if (index != null) data["index"] = index;

    await _platform.invokeMapMethod("update", data);
  }

  static ApplicationState? _instance;
  static final _instanceLock = Lock();

  /// Get the singleton instance of [ApplicationState], create one if neccessary
  static Future<ApplicationState> create() => _instanceLock.run(
        () async {
          Future<ApplicationState> createState() async {
            var database = await openDatabase(
              join(await getDatabasesPath(), "mp3_player.db"),
              onOpen: (database) async {
                var batch = database.batch();
                batch.execute("CREATE TABLE IF NOT EXISTS playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, items TEXT NOT NULL, created_at TEXT NOT NULL);");
                await batch.commit(noResult: true);
              },
            );

            var state = ApplicationState._(database: database);
            return state;
          }

          return _instance ??= await createState();
        },
      );
}
