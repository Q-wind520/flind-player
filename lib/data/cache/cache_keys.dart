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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/codec/source_track_id_codec.dart';

/// Canonical `audio_cache.source_track_id` value for [track].
///
/// Delegates to the shared codec, so the key is the absolute path for `local`
/// tracks, `bvid:cid` for Bilibili and the song id string for NetEase. The
/// download manager and the cache-first resolver must agree on this key or
/// lookups miss.
String cacheSourceTrackId(Track track) => encodeSourceTrackId(track.sourceTrackId);
