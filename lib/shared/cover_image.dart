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

import 'package:flutter/widgets.dart';

/// Displays a cover image decoded at the display size instead of the source's
/// full resolution, reducing raster memory when many covers are visible.
///
/// [path] (a cached local file) takes priority; otherwise [url] (a transient
/// remote image) is used. When [size] is finite the widget is exactly [size]
/// logical pixels square and the image is decoded at `size * devicePixelRatio`
/// physical pixels. When [size] is `double.infinity` the widget fills its
/// parent (preserving the existing grid-card semantics) and a [LayoutBuilder]
/// derives the decode edge from the actual constraints.
///
/// `cacheWidth` is what keeps memory bounded: covers are already cached on disk
/// at roughly 512px, but decoding that cache at full size would allocate a
/// bitmap far larger than the on-screen thumbnail, per visible item.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.path,
    this.url,
    required this.size,
    this.errorBuilder,
  });

  /// File path to the cached cover image, if one exists locally.
  final String? path;

  /// Remote URL for a transient cover image, used when [path] is absent.
  final String? url;

  /// Logical edge length in pixels, or `double.infinity` to fill the parent.
  final double size;

  /// Optional error builder forwarded to the underlying [Image].
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final filePath = path;
    final remoteUrl = url;

    if (filePath != null && filePath.isNotEmpty) {
      return _buildAtDisplaySize(
        dpr: dpr,
        buildImage: (cacheWidth) => Image.file(
          File(filePath),
          width: _edge,
          height: _edge,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          // A stale pointer (the cached file was evicted) must not go blank
          // when the remote URL is still known: fall back to the network.
          errorBuilder: (context, error, stackTrace) =>
              _networkOrError(context, remoteUrl, error, stackTrace),
        ),
      );
    }

    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return _buildAtDisplaySize(
        dpr: dpr,
        buildImage: (cacheWidth) => Image.network(
          remoteUrl,
          width: _edge,
          height: _edge,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: errorBuilder,
        ),
      );
    }

    return errorBuilder?.call(context, 'No cover', null) ??
        const SizedBox.shrink();
  }

  /// `null` while [size] is infinite so the fill branch keeps intrinsic sizing.
  double? get _edge => size.isFinite ? size : null;

  /// Renders [remoteUrl] when it is known, otherwise delegates to
  /// [errorBuilder] (or an empty box). Used as the file branch's error handler.
  Widget _networkOrError(
    BuildContext context,
    String? remoteUrl,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return _buildAtDisplaySize(
        dpr: MediaQuery.devicePixelRatioOf(context),
        buildImage: (cacheWidth) => Image.network(
          remoteUrl,
          width: _edge,
          height: _edge,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: errorBuilder,
        ),
      );
    }
    return errorBuilder?.call(context, error, stackTrace) ??
        const SizedBox.shrink();
  }

  /// Shared size strategy: a decode edge of `size * dpr` for fixed covers, or
  /// a [LayoutBuilder]-derived edge when [size] is infinite.
  Widget _buildAtDisplaySize({
    required double dpr,
    required Widget Function(int cacheWidth) buildImage,
  }) {
    if (size.isFinite) {
      return buildImage((size * dpr).round());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final edge = constraints.maxWidth;
        final physicalEdge = edge.isFinite ? (edge * dpr).round() : 512;
        return buildImage(physicalEdge);
      },
    );
  }
}
