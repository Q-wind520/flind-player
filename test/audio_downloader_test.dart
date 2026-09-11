// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/cache/audio_downloader.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('flind_audio_downloader');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  /// Binds a loopback HTTP server and registers [handler] for every request.
  Future<HttpServer> startServer(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handler);
    addTearDown(() => server.close(force: true));
    return server;
  }

  Uri urlFor(HttpServer server) =>
      Uri.parse('http://127.0.0.1:${server.port}/audio.m4s');

  File targetFile() => File('${dir.path}/audio.m4a');

  test('downloads a full 200 response and reports a final 100%', () async {
    final payload = List<int>.generate(4096, (i) => i % 256);
    final server = await startServer((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentLength = payload.length
        ..add(payload);
      await request.response.close();
    });

    final target = targetFile();
    final progress = <(int, int?)>[];
    final downloader = AudioDownloader(sleeper: (_) async {});

    final bytes = await downloader.download(
      url: urlFor(server),
      headers: const <String, String>{},
      target: target,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(bytes, payload.length);
    expect(target.existsSync(), isTrue);
    expect(target.readAsBytesSync(), payload);
    expect(File('${target.path}.part').existsSync(), isFalse);
    expect(progress, isNotEmpty);
    expect(progress.last, (payload.length, payload.length));
  });

  test('resumes from an existing .part file using Range', () async {
    final payload = List<int>.generate(8192, (i) => i % 256);
    final half = payload.length ~/ 2;
    final ranges = <String?>[];
    final server = await startServer((request) async {
      ranges.add(request.headers.value('range'));
      if (request.headers.value('range') == 'bytes=$half-') {
        request.response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $half-${payload.length - 1}/${payload.length}',
          )
          ..headers.contentLength = payload.length - half
          ..add(payload.sublist(half));
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = payload.length
          ..add(payload);
      }
      await request.response.close();
    });

    final target = targetFile();
    final part = File('${target.path}.part')
      ..createSync(recursive: true)
      ..writeAsBytesSync(payload.sublist(0, half));

    final progress = <(int, int?)>[];
    final downloader = AudioDownloader(sleeper: (_) async {});
    final bytes = await downloader.download(
      url: urlFor(server),
      headers: const <String, String>{},
      target: target,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(ranges, <String?>['bytes=$half-']);
    expect(bytes, payload.length);
    expect(target.readAsBytesSync(), payload);
    expect(part.existsSync(), isFalse);
    expect(progress.last, (payload.length, payload.length));
  });

  test(
    'restarts cleanly when the server ignores Range and answers 200',
    () async {
      final payload = List<int>.generate(4096, (i) => i % 256);
      final ranges = <String?>[];
      final server = await startServer((request) async {
        ranges.add(request.headers.value('range'));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = payload.length
          ..add(payload);
        await request.response.close();
      });

      final target = targetFile();
      final part = File('${target.path}.part')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(1000, 7));

      final downloader = AudioDownloader(sleeper: (_) async {});
      final bytes = await downloader.download(
        url: urlFor(server),
        headers: const <String, String>{},
        target: target,
        onProgress: (_, _) {},
      );

      // The request still carried a Range, but the 200 forced a restart.
      expect(ranges, <String?>['bytes=1000-']);
      expect(bytes, payload.length);
      expect(target.readAsBytesSync(), payload);
      expect(part.existsSync(), isFalse);
    },
  );

  test(
    '403 throws StreamExpiredException immediately without retrying',
    () async {
      var requests = 0;
      final server = await startServer((request) async {
        requests++;
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      });

      final url = urlFor(server);
      var slept = false;
      final downloader = AudioDownloader(
        sleeper: (_) async {
          slept = true;
        },
      );

      await expectLater(
        downloader.download(
          url: url,
          headers: const <String, String>{},
          target: targetFile(),
          onProgress: (_, _) {},
        ),
        throwsA(isA<StreamExpiredException>().having((e) => e.url, 'url', url)),
      );

      expect(requests, 1);
      expect(slept, isFalse);
    },
  );

  test('404 also throws StreamExpiredException immediately', () async {
    var requests = 0;
    final server = await startServer((request) async {
      requests++;
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    final downloader = AudioDownloader(sleeper: (_) async {});
    await expectLater(
      downloader.download(
        url: urlFor(server),
        headers: const <String, String>{},
        target: targetFile(),
        onProgress: (_, _) {},
      ),
      throwsA(isA<StreamExpiredException>()),
    );

    expect(requests, 1);
  });

  test('retries transient failures with exponential backoff', () async {
    final payload = List<int>.generate(2048, (i) => i % 256);
    var requests = 0;
    final server = await startServer((request) async {
      requests++;
      if (requests <= 2) {
        request.response.statusCode = HttpStatus.internalServerError;
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentLength = payload.length
          ..add(payload);
      }
      await request.response.close();
    });

    final delays = <Duration>[];
    final target = targetFile();
    final downloader = AudioDownloader(
      sleeper: (duration) async => delays.add(duration),
    );

    final bytes = await downloader.download(
      url: urlFor(server),
      headers: const <String, String>{},
      target: target,
      onProgress: (_, _) {},
    );

    expect(requests, 3);
    expect(delays, <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
    ]);
    expect(bytes, payload.length);
    expect(target.readAsBytesSync(), payload);
  });

  test('gives up after maxAttempts and reports the attempt count', () async {
    var requests = 0;
    final server = await startServer((request) async {
      requests++;
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    });

    final downloader = AudioDownloader(maxAttempts: 2, sleeper: (_) async {});

    await expectLater(
      downloader.download(
        url: urlFor(server),
        headers: const <String, String>{},
        target: targetFile(),
        onProgress: (_, _) {},
      ),
      throwsA(
        isA<DownloadFailedException>().having((e) => e.attempts, 'attempts', 2),
      ),
    );

    expect(requests, 2);
    // The incomplete .part may remain for a later resume; target must not.
    expect(targetFile().existsSync(), isFalse);
  });
}
