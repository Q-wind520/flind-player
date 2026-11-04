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

// DESIGN REQUIREMENT: the NetEase source must remain remotely disableable. It
// is reachable only through `MusicSource`/`StreamResolver`/`LyricsProvider`
// interfaces so a feature flag can drop it without touching the rest of the app.

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lrc_parser.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/remote_album.dart';
import 'package:flind_player/core/sources/remote_artist.dart';
import 'package:flind_player/core/sources/remote_library.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_mappers.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

/// NetEase Cloud Music as a [MusicSource], [StreamResolver] and [LyricsProvider].
///
/// The source itself works anonymously; a signed-in cookie jar raises the
/// requested stream tier to `exhigh`, with a standard fallback for accounts
/// that cannot access it.
class NeteaseSource
    implements
        MusicSource,
        StreamResolver,
        LyricsProvider,
        RemotePlaylistSource,
        RecommendationSource,
        RemoteSearchSource,
        RemoteAlbumSource,
        RemoteArtistSource,
        LikeSource {
  final NeteaseApi _api;
  final AuthCookieJar? _cookieJar;

  NeteaseSource({required NeteaseApi api, AuthCookieJar? cookieJar})
    : _api = api, // ignore: prefer_initializing_formals
      _cookieJar = cookieJar; // ignore: prefer_initializing_formals

  @override
  String get id => neteaseSourceId;

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(<SourceCapability>{
        SourceCapability.search,
        SourceCapability.streamDirect,
        SourceCapability.login,
      });

  @override
  Future<List<Track>> search(String query, {int page = 1}) async {
    final songs = await _api.searchSongs(query, page: page);
    return songs.map(neteaseSongToTrack).toList(growable: false);
  }

  @override
  Future<Track> fetchTrack(SourceTrackId id) async {
    if (id is! NeteaseTrackId) {
      throw ArgumentError.value(
        id,
        'id',
        'NeteaseSource only accepts NeteaseTrackId',
      );
    }
    final song = await _api.songDetail(id.songId);
    if (song == null) {
      throw StateError('No NetEase song ${id.songId}');
    }
    return neteaseSongToTrack(song);
  }

  /// Alias so [NeteaseSource] can be registered in a `StreamResolver` map.
  @override
  Future<StreamInfo> resolve(Track track) => resolveStream(track);

  @override
  Future<StreamInfo> resolveStream(Track track) async {
    final id = track.sourceTrackId;
    if (id is! NeteaseTrackId) {
      throw UnsupportedError(
        'NeteaseSource cannot resolve a ${id.runtimeType} track',
      );
    }
    final signedIn = _cookieJar?.cookieHeader('netease') != null;
    NeteaseUrlDto? dto;
    if (signedIn) {
      try {
        dto = await _api.songUrl(id.songId, level: 'exhigh');
      } catch (_) {
        // An account without the higher tier can reject the request outright.
        dto = null;
      }
      if (dto?.url == null || dto!.url!.isEmpty) {
        dto = await _api.songUrl(id.songId);
      }
    } else {
      dto = await _api.songUrl(id.songId);
    }
    final url = dto?.url;
    if (url == null || url.isEmpty) {
      throw StateError('No stream available for ${track.uri}');
    }
    return StreamInfo(
      url: _streamUri(url),
      headers: const <String, String>{'Referer': kNeteaseReferer},
      qualityId: dto?.level ?? 'standard',
    );
  }

  /// Upgrades a NetEase CDN `http` stream URL to `https`.
  ///
  /// NetEase returns cleartext `http://...music.126.net/...` URLs, which
  /// Android blocks by default; the same URL serves `https` and carries the
  /// same auth query. Non-NetEase or already-secure URLs pass through.
  static Uri _streamUri(String raw) {
    final uri = Uri.parse(raw);
    if (uri.scheme == 'http' && uri.host.endsWith('music.126.net')) {
      return uri.replace(scheme: 'https');
    }
    return uri;
  }

  @override
  Future<List<RemotePlaylist>> playlistsForUser(String userId) async {
    final uid = int.tryParse(userId);
    if (uid == null) return const <RemotePlaylist>[];
    final playlists = await _api.userPlaylists(uid);
    return playlists.map(_playlistToRemote).toList(growable: false);
  }

  @override
  Future<RemoteTrackPage> playlistTracks(
    String playlistId, {
    int page = 1,
  }) async {
    final id = int.tryParse(playlistId);
    if (id == null) {
      return const RemoteTrackPage(
        tracks: <Track>[],
        page: 1,
        hasMore: false,
        totalCount: 0,
      );
    }
    final detail = await _api.playlistDetail(id);
    final tracks = detail == null
        ? const <Track>[]
        : detail.songs.map(neteaseSongToTrack).toList(growable: false);
    return RemoteTrackPage(
      tracks: tracks,
      page: 1,
      hasMore: false,
      totalCount: tracks.length,
    );
  }

  @override
  Future<List<RemotePlaylist>> recommendedPlaylists({int limit = 30}) async {
    final playlists = await _api.recommendedPlaylists(limit: limit);
    return playlists.map(_playlistToRemote).toList(growable: false);
  }

  @override
  Future<List<RemotePlaylist>> popularPlaylists({int limit = 30}) async {
    final playlists = await _api.highQualityPlaylists(limit: limit);
    return playlists.map(_playlistToRemote).toList(growable: false);
  }

  @override
  Future<List<Track>> recommendedSongs() async {
    final songs = await _api.recommendedSongs();
    return songs.map(neteaseSongToTrack).toList(growable: false);
  }

  @override
  Future<List<RemoteAlbum>> searchAlbums(String query, {int page = 1}) async {
    final albums = await _api.searchAlbums(query, page: page);
    return albums.map(_albumToRemote).toList(growable: false);
  }

  @override
  Future<List<RemoteArtist>> searchArtists(String query, {int page = 1}) async {
    final artists = await _api.searchArtists(query, page: page);
    return artists.map(_artistToRemote).toList(growable: false);
  }

  @override
  Future<RemoteAlbum?> album(String albumId) async {
    final id = int.tryParse(albumId);
    if (id == null) return null;
    final detail = await _api.albumDetail(id);
    return detail == null ? null : _albumToRemote(detail.album);
  }

  @override
  Future<RemoteTrackPage> albumTracks(String albumId, {int page = 1}) async {
    final id = int.tryParse(albumId);
    if (id == null) {
      return const RemoteTrackPage(
        tracks: <Track>[],
        page: 1,
        hasMore: false,
        totalCount: 0,
      );
    }
    final detail = await _api.albumDetail(id);
    final tracks = detail == null
        ? const <Track>[]
        : detail.songs.map(neteaseSongToTrack).toList(growable: false);
    return RemoteTrackPage(
      tracks: tracks,
      page: 1,
      hasMore: false,
      totalCount: tracks.length,
    );
  }

  @override
  Future<RemoteArtist?> artist(String artistId) async {
    final id = int.tryParse(artistId);
    if (id == null) return null;
    final artist = await _api.artistDetail(id);
    return artist == null ? null : _artistToRemote(artist);
  }

  @override
  Future<RemoteTrackPage> artistSongs(String artistId, {int page = 1}) async {
    final id = int.tryParse(artistId);
    if (id == null) {
      return const RemoteTrackPage(
        tracks: <Track>[],
        page: 1,
        hasMore: false,
        totalCount: 0,
      );
    }
    final songs = await _api.artistSongs(id, offset: (page - 1) * 100);
    final tracks = songs.map(neteaseSongToTrack).toList(growable: false);
    return RemoteTrackPage(
      tracks: tracks,
      page: page,
      hasMore: songs.length >= 100,
      totalCount: tracks.length,
    );
  }

  @override
  Future<List<RemoteAlbum>> artistAlbums(
    String artistId, {
    int page = 1,
  }) async {
    final id = int.tryParse(artistId);
    if (id == null) return const <RemoteAlbum>[];
    final albums = await _api.artistAlbums(id, offset: (page - 1) * 50);
    return albums.map(_albumToRemote).toList(growable: false);
  }

  @override
  Future<Set<String>> likedTrackIds(String userId) async {
    final uid = int.tryParse(userId);
    if (uid == null) return <String>{};
    final ids = await _api.likedSongIds(uid);
    return ids.map((id) => '$id').toSet();
  }

  @override
  Future<void> setLiked(String trackId, bool liked) async {
    final id = int.tryParse(trackId);
    if (id == null) return;
    await _api.setLiked(id, liked);
  }

  RemotePlaylist _playlistToRemote(NeteasePlaylistDto playlist) {
    return RemotePlaylist(
      id: '${playlist.id}',
      title: playlist.name,
      coverUrl: playlist.coverUrl,
      trackCount: playlist.trackCount,
    );
  }

  RemoteAlbum _albumToRemote(NeteaseAlbumDto album) {
    return RemoteAlbum(
      id: '${album.id}',
      title: album.name,
      coverUrl: album.coverUrl,
      artist: album.artist,
      trackCount: album.trackCount,
      year: album.publishTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(album.publishTime!).year,
    );
  }

  RemoteArtist _artistToRemote(NeteaseArtistDto artist) {
    return RemoteArtist(
      id: '${artist.id}',
      name: artist.name,
      avatarUrl: artist.avatarUrl,
      albumCount: artist.albumCount,
      songCount: artist.songCount,
    );
  }

  @override
  Future<Lyric?> lyricsFor(Track track) async {
    final id = track.sourceTrackId;
    if (id is! NeteaseTrackId) return null;
    final dto = await _api.songLyric(id.songId);
    // Prefer YRC: it carries word timings and usually the same translated
    // lines; plain LRC remains the fallback for older/anonymous responses.
    return parseYrc(dto.yrc, translation: dto.yrcTranslation) ??
        parseLrc(dto.lrc, translation: dto.translation);
  }
}
