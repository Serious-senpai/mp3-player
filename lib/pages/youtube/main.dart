import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../drawer.dart";
import "../../src/state.dart";
import "../../src/utils.dart";
import "../../src/youtube/search.dart";
import "../../src/youtube/widgets.dart";

enum YouTubeSearchingState {
  IDLING,
  LOADING_MORE,
  SEARCHING,
}

class YouTubePage extends StatefulWidget {
  final ApplicationState state;

  const YouTubePage({required this.state, super.key});

  @override
  State<YouTubePage> createState() => _YouTubePageState();
}

class _YouTubePageState extends State<YouTubePage> with PageStateWithDrawer<YouTubePage> {
  ApplicationState get state => widget.state;
  final TextEditingController searchController = TextEditingController();

  YouTubeSearchingState searchingState = YouTubeSearchingState.IDLING;
  String? currentQuery;
  final page = <SearchType, int>{};

  SearchResult? _searchResult;
  SearchResult get searchResult => _searchResult ??= SearchResult.empty(client: state.ytClient);

  void refresh() {
    if (mounted) setState(() {});
  }

  void resetSearchingState({required String query}) {
    currentQuery = query;
    searchResult.empty();
    page.clear();
  }

  Future<void> newSearch() async {
    if (searchingState != YouTubeSearchingState.IDLING) return;

    resetSearchingState(query: searchController.text);
    searchingState = YouTubeSearchingState.SEARCHING;
    refresh();

    var error = false;
    for (var type in SearchType.values) {
      var result = await SearchResult.get(
        searchController.text,
        page: page[type] = 0,
        type: type,
        client: state.ytClient,
      );

      if (result == null) {
        error = true;
      } else {
        searchResult.update(result);
      }
    }

    if (error) {
      await showToast("Some results couldn't be loaded.");
    }

    searchingState = YouTubeSearchingState.IDLING;
    refresh();
  }

  Future<bool> loadMore({required SearchType type}) async {
    if (searchingState == YouTubeSearchingState.IDLING && currentQuery != null) {
      await showToast("Loading more results");
      searchingState = YouTubeSearchingState.LOADING_MORE;
      refresh();

      var newPage = page[type]! + 1;
      return await SearchResult.get(
        currentQuery!,
        page: newPage,
        type: type,
        client: state.ytClient,
      ).then(
        (result) async {
          try {
            if (result == null) {
              await showToast("Please check your connection and try again.");
              return false;
            } else {
              searchResult.update(result);
              page[type] = newPage;
              return true;
            }
          } finally {
            searchingState = YouTubeSearchingState.IDLING;
            refresh();
          }
        },
      );
    }

    return false;
  }

  @override
  Scaffold buildScaffold(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          onPressed: openDrawer,
          icon: const Icon(Icons.equalizer_outlined),
        ),
        title: const Text("YouTube MP3 Downloader"),
      ),
      drawer: createDrawer(context: context, state: state),
      body: DefaultTabController(
        length: 3,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          height: screenSize.height,
          width: screenSize.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: searchController,
                decoration: const InputDecoration.collapsed(hintText: "Enter searching query"),
                keyboardType: TextInputType.text,
                showCursor: true,
                autofocus: true,
                enableSuggestions: false,
                maxLength: 50,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                onSubmitted: (_) => newSearch(),
              ),
              const TabBar(
                tabs: [
                  Tab(text: "Videos"),
                  Tab(text: "Playlists"),
                  Tab(text: "Channels"),
                ],
              ),
              searchingState == YouTubeSearchingState.SEARCHING
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(child: loadingIndicator()),
                    )
                  : searchResult.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: Text("Enter a searching query to start")),
                        )
                      : Expanded(
                          child: TabBarView(
                            children: [
                              ListView.builder(
                                itemBuilder: (context, index) => index < searchResult.videos.length
                                    ? VideoWidget(video: searchResult.videos[index], width: screenSize.width)
                                    : TextButton(
                                        onPressed: () => loadMore(type: SearchType.video),
                                        child: const Text("Load more results"),
                                      ),
                                itemCount: searchResult.videos.length + 1,
                              ),
                              ListView.builder(
                                itemBuilder: (context, index) => index < searchResult.playlists.length
                                    ? PlaylistWidget(playlist: searchResult.playlists[index], width: screenSize.width)
                                    : TextButton(
                                        onPressed: () => loadMore(type: SearchType.playlist),
                                        child: const Text("Load more results"),
                                      ),
                                itemCount: searchResult.playlists.length + 1,
                              ),
                              ListView.builder(
                                itemBuilder: (context, index) => index < searchResult.channels.length
                                    ? ChannelWidget(channel: searchResult.channels[index], width: screenSize.width)
                                    : TextButton(
                                        onPressed: () => loadMore(type: SearchType.channel),
                                        child: const Text("Load more results"),
                                      ),
                                itemCount: searchResult.channels.length + 1,
                              ),
                            ],
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
