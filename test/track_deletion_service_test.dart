import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cache_keys.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
import 'package:flind_player/data/repositories/drift_playlist_repository.dart';
import 'package:flind_player/data/services/track_deletion_service.dart';

class _NoopSettings implements SettingsRepository {
  @override
  Future<CacheSettings> cacheSettings() async => CacheSettings.defaults;
  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {}
  @override
  Stream<CacheSettings> watchCacheSettings() => const Stream.empty();
  @override
  Future<TrackSort> librarySort() async => TrackSort.recentlyAdded;
  @override
  Future<void> setLibrarySort(TrackSort sort) async {}
  @override
  Future<LibraryViews> libraryViews() async => LibraryViews.defaults;
  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {}
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;
  @override
  Future<void> setAppLanguage(AppLanguage language) async {}
  @override
  Future<AppThemeMode> appThemeMode() async => AppThemeMode.system;
  @override
  Future<void> setAppThemeMode(AppThemeMode mode) async {}
}

Track _track({int? id}) => Track(
  id: id,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Alpha',
);

void main() {
  late AppDatabase db;
  late Directory cacheDir;
  late AudioCacheStore cache;
  late DriftMusicLibraryRepository library;
  late DriftPlaylistRepository playlists;
  late TrackDeletionService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cacheDir = Directory.systemTemp.createTempSync('deletion_test');
    cache = AudioCacheStore(
      database: db,
      baseDir: cacheDir,
      settings: _NoopSettings(),
    );
    library = DriftMusicLibraryRepository(db);
    playlists = DriftPlaylistRepository(db);
    service = TrackDeletionService(
      cache: cache,
      playlists: playlists,
      library: library,
    );
  });

  tearDown(() async {
    await db.close();
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  test('deletes the library row, all memberships and the cache entry',
      () async {
    final track = _track();
    final id = await library.upsertTrack(track);
    final withId = track.copyWith(id: id);
    final playlist = await playlists.createPlaylist(name: 'A');
    await playlists.addTrack(playlist.id, withId);
    await playlists.addTrack(favoritesPlaylistId, withId);

    final file = File('${cacheDir.path}/local/a.m4a')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await cache.insert(
      source: 'local',
      sourceTrackId: cacheSourceTrackId(withId),
      filePath: file.path,
      bytes: 3,
      qualityId: 'q',
      pinned: true,
      contentHash: 'hash-a',
    );

    await service.deleteEverywhere(withId);

    expect(await library.findByUri(withId.uri), isNull);
    expect(await playlists.containsTrack(playlist.id, withId.uri), isFalse);
    expect(await cache.lookup('local', cacheSourceTrackId(withId)), isNull);
    expect(file.existsSync(), isFalse);
  });

  test('an unavailable track (id == null) still clears memberships', () async {
    final track = _track();
    final playlist = await playlists.createPlaylist(name: 'A');
    await playlists.addTrack(playlist.id, track);

    await service.deleteEverywhere(track);

    expect(await playlists.containsTrack(playlist.id, track.uri), isFalse);
  });
}
