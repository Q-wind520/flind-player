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

import 'package:flutter/material.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/shared/cover_image.dart';

/// The [Hero] tag shared by the mini-player cover and the full-screen player
/// cover, derived from the track uri so both ends of the flight match.
String playerCoverHeroTag(String uri) => 'player-cover:$uri';

/// Wraps a cover in a [Hero] that flies between the mini player bar and the
/// full-screen player.
///
/// The flight shuttle renders a cover filling the interpolated rect with the
/// large radius, so the artwork grows/shrinks smoothly instead of snapping to
/// the destination's fixed size mid-flight. A coverless track flies a tonal
/// music-note placeholder rather than a blank hole.
class CoverHero extends StatelessWidget {
  const CoverHero({
    super.key,
    required this.uri,
    this.coverPath,
    this.coverUrl,
    required this.child,
  });

  /// The track uri the [Hero.tag] is derived from.
  final String uri;

  /// File path to the cached cover, forwarded to the flight shuttle.
  final String? coverPath;

  /// Remote cover url, forwarded to the flight shuttle.
  final String? coverUrl;

  /// The docked cover shown when the hero is not in flight.
  final Widget child;

  bool get _hasCover =>
      (coverPath != null && coverPath!.isNotEmpty) ||
      (coverUrl != null && coverUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Hero(
      tag: playerCoverHeroTag(uri),
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              color: scheme.surfaceContainerHighest,
              child: _hasCover
                  ? CoverImage(
                      path: coverPath,
                      url: coverUrl,
                      size: double.infinity,
                    )
                  : Center(
                      child: Icon(
                        Icons.music_note,
                        size: 40,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
      child: child,
    );
  }
}
