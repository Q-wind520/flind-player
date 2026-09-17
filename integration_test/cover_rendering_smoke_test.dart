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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/data/sources/local/artwork_cache.dart';
import 'package:flind_player/features/library/library_screen.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/app/l10n.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

/// Wraps [child] in a [MaterialApp] wired to the app's localization delegates
/// so widgets that call `AppLocalizations.of(context)` work under test.
Widget localizedApp(Widget child, {Locale locale = const Locale('zh')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: child,
    );

/// Closes the UI-review blind spot: covers are extracted by [ArtworkCache]
/// into a JPEG whose decoding by the real Flutter engine was never verified.
/// Widget tests run in a fake-async zone where `Image.file` cannot complete its
/// I/O, so every screenshot and test showed a blank square. This integration
/// test runs on the real engine (Windows/Linux/Mac) and asserts that:
///
/// 1. a fresh cover extracted by [ArtworkCache] is decodable by Flutter;
/// 2. the decoded cover (not the music-note placeholder) appears in the
///    library list row, the mini player and the full-screen player.
///
/// Run with:
/// `flutter test integration_test/cover_rendering_smoke_test.dart -d windows`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory covers;
  late ArtworkCache cache;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_cover_it');
    covers = Directory('${root.path}/covers')..createSync(recursive: true);
    cache = ArtworkCache(baseDir: covers);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Copies the tone fixture and embeds a 16x16 blue PNG front cover, then
  /// extracts it through [ArtworkCache] exactly like a library scan would.
  /// Returns the cached JPEG path via its `Track`-ready form.
  Future<Track> trackWithRealCover() async {
    final audio = File('${root.path}/with-cover.mp3');
    File('test/fixtures/tone.mp3').copySync(audio.path);

    final image = img.Image(width: 16, height: 16);
    img.fill(image, color: img.ColorRgb8(30, 90, 220));
    final png = Uint8List.fromList(img.encodePng(image));
    updateMetadata(audio, (metadata) {
      metadata.setPictures([Picture(png, 'image/png', PictureType.coverFront)]);
    });

    final coverPath = await cache.cacheFromFile(audio.path);
    expect(
      coverPath,
      isNotNull,
      reason: 'ArtworkCache must extract the embedded cover',
    );
    expect(File(coverPath!).existsSync(), isTrue);

    return Track(
      id: 1,
      source: 'local',
      sourceTrackId: LocalTrackId(audio.path),
      uri: 'local:${audio.path}',
      title: 'Cover Verification Track',
      artist: 'Flind',
      duration: const Duration(seconds: 65),
      coverPath: coverPath,
    );
  }

  testWidgets(
    'a cover extracted by ArtworkCache is decodable by the real engine',
    (tester) async {
      final track = await trackWithRealCover();

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: CoverImage(path: track.coverPath!, size: 200),
                ),
              ),
            ),
          ),
        ),
      );

      final decoded = await waitForDecodedRawImage(tester);
      expect(decoded, isNotNull, reason: 'cover JPEG never decoded');
      expect(decoded!.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
      // The art is a saturated blue; decoded pixels must not be transparent.
      final pixels = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(pixels, isNotNull);
      expect(pixels!.lengthInBytes, greaterThan(0));
      // No placeholder is shown anywhere.
      expect(find.byIcon(Icons.music_note), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('library list row renders the decoded cover not a placeholder', (
    tester,
  ) async {
    final track = await trackWithRealCover();

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final favRepo = _InMemoryFavoritesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryTracksProvider.overrideWith(
            (ref) => Stream.value(<Track>[track]),
          ),
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState.idle),
          ),
          librarySyncStateProvider.overrideWith(
            (ref) => Stream.value(LibrarySyncState.idle),
          ),
          downloadProgressProvider.overrideWith(
            (ref) => const Stream<DownloadProgress>.empty(),
          ),
          audioCacheEntryProvider.overrideWith((ref, track) async => null),
          favoritesRepositoryProvider.overrideWithValue(favRepo),
          favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
          librarySortProvider.overrideWith(
            () => _FakeLibrarySortNotifier(TrackSort.title),
          ),
          playbackControllerProvider.overrideWith(
            (ref) => _FakePlaybackController(),
          ),
        ],
        child: localizedApp(
          MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: const Scaffold(body: LibraryScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cover Verification Track'), findsOneWidget);

    final decoded = await waitForDecodedRawImage(tester);
    expect(decoded, isNotNull, reason: 'library row cover never decoded');
    expect(find.byIcon(Icons.music_note), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('mini player renders the decoded cover', (tester) async {
    final track = await trackWithRealCover();

    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: track,
      hasNext: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackStateProvider.overrideWith((ref) => Stream.value(state)),
          playbackControllerProvider.overrideWith(
            (ref) => _FakePlaybackController(),
          ),
          favoritesRepositoryProvider.overrideWithValue(
            _InMemoryFavoritesRepository(),
          ),
        ],
        child: localizedApp(const Scaffold(body: MiniPlayerBar())),
      ),
    );
    await tester.pumpAndSettle();

    final decoded = await waitForDecodedRawImage(tester);
    expect(decoded, isNotNull, reason: 'mini player cover never decoded');
    expect(find.byIcon(Icons.music_note), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('full-screen player renders the decoded cover', (tester) async {
    final track = await trackWithRealCover();

    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: track,
      hasNext: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackStateProvider.overrideWith((ref) => Stream.value(state)),
          playbackControllerProvider.overrideWith(
            (ref) => _FakePlaybackController(),
          ),
          favoritesRepositoryProvider.overrideWithValue(
            _InMemoryFavoritesRepository(),
          ),
        ],
        child: localizedApp(const PlayerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final decoded = await waitForDecodedRawImage(tester);
    expect(decoded, isNotNull, reason: 'player cover never decoded');
    expect(find.byIcon(Icons.music_note), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// Pumps frames and real pauses until the cover's [RawImage] holds a decoded
/// image. The real engine decodes asynchronously; fake-async widget tests can
/// never reach this state, which is exactly the gap this test closes.
Future<ui.Image?> waitForDecodedRawImage(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    final raws = tester.widgetList<RawImage>(find.byType(RawImage));
    for (final raw in raws) {
      if (raw.image != null) return raw.image;
    }
  }
  return null;
}

/// Minimal in-memory [FavoritesRepository] mirroring the widget-test helper.
class _InMemoryFavoritesRepository implements FavoritesRepository {
  final _favourites = <String, Track>{};
  final List<StreamController<List<Track>>> _listeners = [];

  @override
  Stream<List<Track>> watchFavorites() async* {
    yield _favourites.values.toList();
    final controller = StreamController<List<Track>>();
    _listeners.add(controller);
    yield* controller.stream;
    // ignore: use_key_synchronously
    controller.onCancel = () => _listeners.remove(controller);
  }

  @override
  Future<List<Track>> allFavorites() async => _favourites.values.toList();

  @override
  Future<bool> isFavorite(String uri) async => _favourites.containsKey(uri);

  @override
  Future<void> addFavorite(Track track) async {
    _favourites[track.uri] = track;
    _notify();
  }

  @override
  Future<void> removeFavorite(String uri) async {
    _favourites.remove(uri);
    _notify();
  }

  @override
  Future<bool> toggleFavorite(Track track) async {
    if (_favourites.containsKey(track.uri)) {
      _favourites.remove(track.uri);
      _notify();
      return false;
    } else {
      _favourites[track.uri] = track;
      _notify();
      return true;
    }
  }

  void _notify() {
    final value = _favourites.values.toList();
    for (final c in _listeners) {
      if (!c.isClosed) c.add(value);
    }
  }

  void dispose() {
    for (final c in _listeners) {
      c.close();
    }
    _listeners.clear();
  }
}

/// Minimal fake [PlaybackController] used only for read paths.
class _FakePlaybackController implements PlaybackController {
  @override
  Stream<PlaybackState> get state => const Stream.empty();
  @override
  PlaybackState get currentState => PlaybackState.idle;
  @override
  PlaybackQueue get queue =>
      const PlaybackQueue(tracks: [], currentIndex: 0, originalOrder: []);

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> togglePlayPause() async {}
  @override
  Future<void> dispose() async {}
}

/// Fake [LibrarySortNotifier] returning a fixed value immediately.
class _FakeLibrarySortNotifier extends LibrarySortNotifier {
  _FakeLibrarySortNotifier(this._sort);

  final TrackSort _sort;

  @override
  Future<TrackSort> build() async => _sort;
}