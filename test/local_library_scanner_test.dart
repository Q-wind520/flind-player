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

import 'package:flind_player/data/sources/local/local_library_scanner.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

void main() {
  late Directory root;
  late LocalLibraryScanner scanner;

  final fixture = File('test/fixtures/tone.mp3');

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_scanner');
    scanner = LocalLibraryScanner(reader: LocalMetadataReader());
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Copies the tone fixture to `<root>/<relativePath>`, creating parents.
  File copyFixture(String relativePath) {
    final target = File('${root.path}/$relativePath');
    target.parent.createSync(recursive: true);
    fixture.copySync(target.path);
    return target;
  }

  test(
    'discovers nested audio, ignores non-audio and extracts metadata',
    () async {
      copyFixture('tone.mp3');
      copyFixture('a/b/tone2.mp3');
      copyFixture('a/b/c/deep.mp3');
      File('${root.path}/readme.txt').writeAsStringSync('not audio');
      File('${root.path}/cover.jpg').writeAsBytesSync(const [1, 2, 3]);

      final result = await scanner.scan(roots: [root.path]);

      expect(result.discovered, 3);
      expect(result.tracks, hasLength(3));
      expect(result.unreadable, 0);
      expect(
        result.tracks.map((track) => track.title),
        everyElement('Flind Test Tone'),
      );
      expect(
        result.tracks.any((track) => track.uri.endsWith('/a/b/c/deep.mp3')),
        isTrue,
        reason: 'files in nested directories must be discovered',
      );
      expect(
        result.tracks.every((track) => track.uri.startsWith('local:')),
        isTrue,
      );
    },
  );

  test('counts unreadable files without aborting the scan', () async {
    copyFixture('good.mp3');
    File('${root.path}/empty.mp3').createSync();

    final result = await scanner.scan(roots: [root.path]);

    expect(result.discovered, 2);
    expect(result.tracks, hasLength(1));
    expect(result.tracks.single.title, 'Flind Test Tone');
    expect(result.unreadable, 1);
  });

  test('skips a missing root without throwing', () async {
    copyFixture('good.mp3');

    final result = await scanner.scan(
      roots: ['${root.path}/does-not-exist', root.path],
    );

    expect(result.tracks, hasLength(1));
    expect(result.discovered, 1);
  });

  test('deduplicates files reachable from overlapping roots', () async {
    copyFixture('a/tone.mp3');

    final result = await scanner.scan(roots: [root.path, '${root.path}/a']);

    expect(result.tracks, hasLength(1));
  });

  test('emits monotonic progress ending in a done event', () async {
    copyFixture('a.mp3');
    copyFixture('b.mp3');
    copyFixture('c.mp3');
    final events = <ScanProgress>[];

    final result = await scanner.scan(
      roots: [root.path],
      onProgress: events.add,
    );

    expect(events, isNotEmpty);
    expect(events.last.done, isTrue);
    expect(events.last.discovered, 3);
    expect(events.last.processed, 3);

    for (var i = 1; i < events.length; i++) {
      expect(
        events[i].discovered,
        greaterThanOrEqualTo(events[i - 1].discovered),
      );
      expect(
        events[i].processed,
        greaterThanOrEqualTo(events[i - 1].processed),
      );
    }
    expect(result.tracks, hasLength(3));
  });

  test('scans multiple roots into one result', () async {
    copyFixture('first/a.mp3');
    final second = Directory('${root.path}/second')
      ..createSync(recursive: true);
    fixture.copySync('${second.path}/b.mp3');

    final result = await scanner.scan(
      roots: ['${root.path}/first', second.path],
    );

    expect(result.tracks, hasLength(2));
  });

  /// Fingerprint of [file] as the scanner would compute it from its stat.
  FileFingerprint fingerprintOf(File file) {
    final stat = file.statSync();
    return FileFingerprint(
      sizeBytes: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
    );
  }

  test('skips an unchanged file but still reports it as seen', () async {
    final file = copyFixture('known.mp3');
    final knownUri = LocalStreamResolver.uriForPath(file.path);

    final result = await scanner.scan(
      roots: [root.path],
      known: {knownUri: fingerprintOf(file)},
    );

    expect(result.tracks, isEmpty);
    expect(result.processed, 0);
    expect(result.unreadable, 0);
    expect(result.discovered, 1);
    expect(result.seenUris, {knownUri});
    expect(result.scannedTracks, isEmpty);
    expect(result.discoveredFiles, hasLength(1));
    expect(result.discoveredFiles.single.uri, knownUri);
    expect(result.discoveredFiles.single.root, root.path);
  });

  test('re-parses a file whose mtime changed', () async {
    final file = copyFixture('touched.mp3');
    final uri = LocalStreamResolver.uriForPath(file.path);
    final stat = file.statSync();
    final stale = FileFingerprint(
      sizeBytes: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch - 1000,
    );

    final result = await scanner.scan(roots: [root.path], known: {uri: stale});

    expect(result.processed, 1);
    expect(result.scannedTracks, hasLength(1));
    expect(result.scannedTracks.single.file.uri, uri);
    expect(
      result.scannedTracks.single.file.mtimeMs,
      file.statSync().modified.millisecondsSinceEpoch,
    );
  });

  test('re-parses a file whose size changed', () async {
    final file = copyFixture('resized.mp3');
    final uri = LocalStreamResolver.uriForPath(file.path);
    final stat = file.statSync();
    final stale = FileFingerprint(
      sizeBytes: stat.size + 1,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
    );

    final result = await scanner.scan(roots: [root.path], known: {uri: stale});

    expect(result.processed, 1);
    expect(result.scannedTracks, hasLength(1));
  });

  test('treats a fingerprint with null fields as stale', () async {
    final file = copyFixture('legacy.mp3');
    final uri = LocalStreamResolver.uriForPath(file.path);

    final result = await scanner.scan(
      roots: [root.path],
      known: {uri: const FileFingerprint()},
    );

    expect(result.processed, 1);
    expect(result.scannedTracks, hasLength(1));
  });

  test('reports every discovered file but only parsed tracks', () async {
    final unchanged = copyFixture('unchanged.mp3');
    final changed = copyFixture('changed.mp3');
    final changedUri = LocalStreamResolver.uriForPath(changed.path);

    final result = await scanner.scan(
      roots: [root.path],
      known: {
        LocalStreamResolver.uriForPath(unchanged.path): fingerprintOf(unchanged),
        changedUri: const FileFingerprint(sizeBytes: 0, mtimeMs: 0),
      },
    );

    expect(result.discovered, 2);
    expect(result.discoveredFiles, hasLength(2));
    expect(result.scannedTracks, hasLength(1));
    expect(result.scannedTracks.single.file.uri, changedUri);
    expect(result.processed, 1);
  });

  test('records the discovered size and mtime in the fingerprint', () async {
    final file = copyFixture('fingerprinted.mp3');

    final result = await scanner.scan(roots: [root.path]);
    final stat = file.statSync();

    expect(result.discoveredFiles.single.sizeBytes, stat.size);
    expect(
      result.discoveredFiles.single.mtimeMs,
      stat.modified.millisecondsSinceEpoch,
    );
    expect(result.scannedTracks.single.file.sizeBytes, stat.size);
  });
}
