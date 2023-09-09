import "dart:convert";

import "package:async_locks/async_locks.dart";
import "package:http/http.dart";

class YouTubeClient {
  static final invidiousInstanceUrl = Uri.https("api.invidious.io", "/instances.json");

  final http = Client();
  final _hosts = <Uri>[];
  final _hostsLock = Lock();

  YouTubeClient();

  Future<void> fillInvidiousInstances() async {
    print("fillInvidiousInstances() started");
    await _hostsLock.run(
      () async {
        try {
          if (_hosts.isEmpty) {
            var response = await http.get(invidiousInstanceUrl);
            if (response.statusCode != 200) return;

            var data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
            for (var instanceData in data) {
              var hostName = instanceData[0] as String;
              var hostData = instanceData[1] as Map<String, dynamic>;
              if (hostName.endsWith(".i2p") || hostName.endsWith(".onion") || hostData["api"] != true) continue;

              _hosts.add(Uri.https(hostName));
            }
          }

          print("Got hosts $_hosts");
        } on ClientException {
          // pass
        }
      },
    );
  }

  Future<Response?> get({
    Iterable<String>? pathSegments,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    await fillInvidiousInstances();
    queryParameters?.putIfAbsent("hl", () => "en-US");

    var failed = <Uri>[];
    var result = await _hostsLock.run(
      () async {
        for (var i = 0; i < _hosts.length; i++) {
          var host = _hosts[i];
          print("GET: $host");

          try {
            var response = await http.get(
              host.replace(
                pathSegments: pathSegments,
                queryParameters: queryParameters,
              ),
              headers: headers,
            );

            _hosts.removeAt(i);
            _hosts.insert(0, host);

            var j = failed.length - 1;
            while (i > 0 && j >= 0) {
              i--;
              if (failed[j] == _hosts[i]) {
                _hosts.removeAt(i);
                _hosts.add(host);
                j--;
              }
            }

            print("Updated hosts to $_hosts");
            return response;
          } on ClientException {
            failed.add(host);
          }
        }
      },
    );

    return result;
  }
}
