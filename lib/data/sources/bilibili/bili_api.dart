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

import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/bilibili/bili_models.dart';
import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/bilibili/risk_control.dart';
import 'package:flind_player/data/sources/bilibili/wbi_signer.dart';

/// Typed access to the Bilibili endpoints the adapter needs.
///
/// Every network call goes through [BiliClient] and [RateLimiter]; the two
/// endpoints that require it are WBI-signed via [WbiSigner]. The risk-control
/// cookie is attached once, lazily, on the first request.
class BiliApi {
  static const String _searchPath = '/x/web-interface/wbi/search/type';
  static const String _viewPath = '/x/web-interface/view';
  static const String _playUrlPath = '/x/player/wbi/playurl';
  static const String _favFoldersPath = '/x/v3/fav/folder/created/list-all';
  static const String _favResourcesPath = '/x/v3/fav/resource/list';

  /// Page size for favourite resources, matching the endpoint's web client.
  static const int favPageSize = 20;

  /// `fnval=4048` requests every DASH capability (DASH + HDR + 4K + Dolby +
  /// Dolby Vision + 8K + AV1).
  static const int dashFnval = 4048;

  final BiliClient _client;
  final WbiSigner _signer;
  final RateLimiter _rateLimiter;
  final RiskControl _riskControl;

  bool _cookieEnsured = false;

  BiliApi({
    required BiliClient client,
    required WbiSigner signer,
    required RateLimiter rateLimiter,
    required RiskControl riskControl,
  }) : _client = client, // ignore: prefer_initializing_formals
       _signer = signer, // ignore: prefer_initializing_formals
       _rateLimiter = rateLimiter, // ignore: prefer_initializing_formals
       _riskControl = riskControl; // ignore: prefer_initializing_formals

  /// Searches videos, stripping nothing here — mapping happens in
  /// [bili_mappers].
  Future<List<SearchItemDto>> searchVideos(
    String keyword, {
    int page = 1,
  }) async {
    await _ensureCookie();
    final params = await _signer.sign(<String, dynamic>{
      'search_type': 'video',
      'keyword': keyword,
      'page': page,
    });
    final json = await _rateLimiter.run(
      () => _client.getJson(_searchPath, query: params),
    );

    final data = json['data'];
    final result = data is Map ? data['result'] : null;
    if (result is! List) return const <SearchItemDto>[];

    return result
        .whereType<Map>()
        .map((e) => SearchItemDto.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.bvid.isNotEmpty)
        .toList(growable: false);
  }

  /// Fetches video metadata (title, owner, `pages[]`). Not WBI-signed.
  Future<VideoInfoDto> videoInfo(String bvid) async {
    await _ensureCookie();
    final json = await _rateLimiter.run(
      () => _client.getJson(_viewPath, query: <String, dynamic>{'bvid': bvid}),
    );
    final data = json['data'];
    if (data is! Map) {
      throw const BiliApiException(-1, 'view response had no data');
    }
    return VideoInfoDto.fromJson(Map<String, dynamic>.from(data));
  }

  /// Resolves the best DASH audio representation for `bvid`/`cid`.
  ///
  /// Returns the highest-`bandwidth` entry, or `null` when the video exposes no
  /// audio stream.
  Future<DashAudioDto?> playUrlAudio(String bvid, int cid) async {
    await _ensureCookie();
    final params = await _signer.sign(<String, dynamic>{
      'bvid': bvid,
      'cid': cid,
      'fnval': dashFnval,
      'fnver': 0,
      'fourk': 1,
    });
    final json = await _rateLimiter.run(
      () => _client.getJson(_playUrlPath, query: params),
    );

    final data = json['data'];
    final dash = data is Map ? data['dash'] : null;
    final audio = dash is Map ? dash['audio'] : null;
    if (audio is! List || audio.isEmpty) return null;

    final entries = audio
        .whereType<Map>()
        .map((e) => DashAudioDto.fromJson(Map<String, dynamic>.from(e)))
        .where((entry) => entry.baseUrl.isNotEmpty)
        .toList(growable: false);
    if (entries.isEmpty) return null;

    entries.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    return entries.first;
  }

  /// Lists [userId]'s **public** favourite folders.
  ///
  /// Anonymous endpoint: no WBI signature and no cookie (the risk-control
  /// fingerprint is intentionally not attached — the endpoint answers without
  /// it). The payload is `data.list[]`, or `data: null` when the account has
  /// published no folder.
  Future<List<FavFolderDto>> favoriteFolders(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return const <FavFolderDto>[];

    final json = await _rateLimiter.run(
      () => _client.getJson(
        _favFoldersPath,
        query: <String, dynamic>{'up_mid': trimmed},
      ),
    );

    final data = json['data'];
    final list = data is Map ? data['list'] : null;
    if (list is! List) return const <FavFolderDto>[];

    return list
        .whereType<Map>()
        .map((e) => FavFolderDto.fromJson(Map<String, dynamic>.from(e)))
        .where((folder) => folder.id.isNotEmpty)
        .toList(growable: false);
  }

  /// Fetches one page of [mediaId]'s resources, newest first.
  ///
  /// Anonymous endpoint: no WBI signature and no cookie. The payload is
  /// `data.medias[]`, or `data: null` for a missing or empty folder.
  Future<List<FavResourceDto>> favoriteResources(
    String mediaId, {
    int page = 1,
  }) async {
    final json = await _rateLimiter.run(
      () => _client.getJson(
        _favResourcesPath,
        query: <String, dynamic>{
          'media_id': mediaId,
          'pn': page,
          'ps': favPageSize,
          'platform': 'web',
        },
      ),
    );

    final data = json['data'];
    final medias = data is Map ? data['medias'] : null;
    if (medias is! List) return const <FavResourceDto>[];

    return medias
        .whereType<Map>()
        .map((e) => FavResourceDto.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Attaches the cached risk-control cookie exactly once.
  ///
  /// The `spi` fetch also goes through [RateLimiter] so no request can bypass
  /// the single-flight pacing.
  Future<void> _ensureCookie() async {
    if (_cookieEnsured) return;
    _cookieEnsured = true;
    final header = await _rateLimiter.run(_riskControl.cookieHeader);
    if (header.isNotEmpty) {
      _client.setCookieHeader(header);
    }
  }
}
