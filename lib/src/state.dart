import "package:async_locks/async_locks.dart";
import "package:flutter/services.dart";
import "package:path/path.dart";
import "package:sqflite/sqflite.dart";

import "playlists.dart";
import "tracks.dart";
import "youtube/client.dart";

/// The global, singleton [ApplicationState]
class ApplicationState {
  static const UPDATE_STATE_CHANNEL_METHOD = "UPDATE_STATE_CHANNEL_METHOD";

  static const INDEX_KEY = "INDEX";
  static const CURRENT_POSITION_KEY = "CURRENT_POSITION";
  static const DURATION_KEY = "DURATION";
  static const IS_PLAYING_KEY = "IS_PLAYING";
  static const PLAYLIST_ID_KEY = "PLAYLIST_ID";
  static const REPEAT_KEY = "REPEAT";
  static const SHUFFLE_KEY = "SHUFFLE";

  /// The application SQLite [Database]
  final Database database;

  /// The application [YouTubeClient]
  final YouTubeClient ytClient = YouTubeClient();

  static const _platform = MethodChannel("com.haruka.mp3_player/player", JSONMethodCodec());

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

  // https://developer.android.com/reference/androidx/media3/common/Player.RepeatMode
  static const REPEAT_MODE_OFF = 0;
  static const REPEAT_MODE_ONE = 1;
  static const REPEAT_MODE_ALL = 2;

  /// The current repeat mode of the player
  ///
  /// See also: https://developer.android.com/reference/androidx/media3/common/Player#getRepeatMode()
  int repeat = REPEAT_MODE_OFF;

  /// The current shuffle mode of the player
  ///
  /// See also: https://developer.android.com/reference/androidx/media3/common/Player#getShuffleModeEnabled()
  bool shuffle = false;

  /// The current position (in milliseconds) of [currentTrack]. This value shouldn't be rely on when no track is playing.
  int currentPosition = 0;

  /// The duration (a.k.a. length) in milliseconds of [currentTrack]. This value shouldn't be rely on when no track is playing.
  int duration = 0;
  final _streamStateEvent = Event();

  ApplicationState._({required this.database}) {
    _platform.setMethodCallHandler(
      (call) async {
        print("Received $call");
        assert(call.method == UPDATE_STATE_CHANNEL_METHOD);
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

  /// Request to the native side that the ExoPlayer should seek to the specified [duration]
  Future<void> seek(Duration duration) => _platform.invokeMapMethod("seek", {"positionMs": duration.inMilliseconds});

  /// Request to the native side to skip to the next track in [currentPlaylist]
  Future<void> next() => _platform.invokeMapMethod("next");

  /// Request to the native side to skip to the previous track in the [currentPlaylist]
  Future<void> previous() => _platform.invokeMapMethod("previous");

  /// Request to the native side to stop the ExoPlayer
  Future<void> stop() => _platform.invokeMapMethod("stop");

  /// Toggle the repeat mode of the native ExoPlayer
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
                batch.execute("CREATE TABLE IF NOT EXISTS titles (path TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL)");
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
