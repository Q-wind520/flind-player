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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/cache/cover_headers.dart';
import 'package:flind_player/data/providers/cover_providers.dart';

/// Displays a cover image decoded at the display size instead of the source's
/// full resolution, reducing raster memory when many covers are visible.
///
/// [path] (a cached local file) takes priority; otherwise [url] (a remote
/// image) is shown **directly first** with the platform's per-host headers
/// (browser UA + `Referer`), and only when that request fails does the widget
/// fall back to downloading the cover through [remoteCoverCacheProvider]
/// (cache-first, validated, layer-2 disk cache) and rendering the cached file.
/// This mirrors NeriPlayer's remote-first + proxy-fallback cover design and
/// keeps a hotlink-protected CDN (e.g. NetEase's `*.music.126.net`) working.
///
/// When [size] is finite the widget is exactly [size] logical pixels square and
/// the image is decoded at `size * devicePixelRatio` physical pixels. When
/// [size] is `double.infinity` the widget fills its parent (preserving the
/// existing grid-card semantics) and a [LayoutBuilder] derives the decode edge
/// from the actual constraints.
///
/// `cacheWidth` is what keeps memory bounded: covers are already cached on disk
/// at roughly 512px, but decoding that cache at full size would allocate a
/// bitmap far larger than the on-screen thumbnail, per visible item.
class CoverImage extends ConsumerStatefulWidget {
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
  ConsumerState<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends ConsumerState<CoverImage> {
  /// Path of a cover fetched through the remote cache after a direct failure.
  String? _cachedPath;

  /// Guards against launching more than one fallback download per URL.
  bool _resolving = false;

  /// Set once the download fallback also failed, so the placeholder sticks.
  bool _failed = false;

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.url != widget.url) {
      _cachedPath = null;
      _resolving = false;
      _failed = false;
    }
  }

  /// `null` while [CoverImage.size] is infinite so the fill branch keeps
  /// intrinsic sizing.
  double? get _edge => widget.size.isFinite ? widget.size : null;

  /// Downloads (cache-first) the remote cover after a direct request failed.
  ///
  /// Deliberately does not `setState` before the first `await`: this runs from
  /// an [Image] error builder, potentially during build.
  Future<void> _fallbackToRemote() async {
    final url = widget.url;
    if (url == null || url.isEmpty || _resolving) return;
    _resolving = true;
    final path = await ref.read(remoteCoverCacheProvider).resolve(url);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      if (path != null) {
        _cachedPath = path;
      } else {
        _failed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final cachedPath = _cachedPath;
    if (cachedPath != null) {
      return _buildAtDisplaySize(
        dpr: dpr,
        buildImage: (cacheWidth) => Image.file(
          File(cachedPath),
          width: _edge,
          height: _edge,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
        ),
      );
    }

    final filePath = widget.path;
    if (filePath != null && filePath.isNotEmpty) {
      return _buildAtDisplaySize(
        dpr: dpr,
        buildImage: (cacheWidth) => Image.file(
          File(filePath),
          width: _edge,
          height: _edge,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: _fileErrorBuilder,
        ),
      );
    }

    final url = widget.url;
    if (!_failed && url != null && url.isNotEmpty) {
      return _buildAtDisplaySize(
        dpr: dpr,
        buildImage: (cacheWidth) => Image.network(
          url,
          width: _edge,
          height: _edge,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          headers: coverHeadersFor(Uri.parse(url)),
          errorBuilder: _networkErrorBuilder,
        ),
      );
    }

    return _errorWidget(context, 'No cover', null);
  }

  /// A stale/evicted local file falls back to the remote (cache-first) path.
  Widget _fileErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    _fallbackToRemote();
    return _errorWidget(context, error, stackTrace);
  }

  /// A direct network failure (e.g. a 403 from a hotlink-protected CDN) falls
  /// back to the download-and-cache path.
  Widget _networkErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    _fallbackToRemote();
    return _errorWidget(context, error, stackTrace);
  }

  Widget _errorWidget(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) =>
      widget.errorBuilder?.call(context, error, stackTrace) ??
      const SizedBox.shrink();

  /// Shared size strategy: a decode edge of `size * dpr` for fixed covers, or
  /// a [LayoutBuilder]-derived edge when [size] is infinite.
  Widget _buildAtDisplaySize({
    required double dpr,
    required Widget Function(int cacheWidth) buildImage,
  }) {
    if (widget.size.isFinite) {
      return buildImage((widget.size * dpr).round());
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
