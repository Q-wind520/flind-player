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

/// Displays a cover image decoded at the display size rather than full cache
/// resolution, reducing memory usage when thumbnails are small.
///
/// When [size] is finite, the widget is exactly [size] logical pixels square and
/// the image is decoded at `size * devicePixelRatio` physical pixels via
/// [ResizeImage]. When [size] is `double.infinity` the widget fills its parent
/// (preserving the existing grid-card semantics) and a [LayoutBuilder] derives
/// the decode edge from the actual constraints.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.path,
    required this.size,
    this.errorBuilder,
  });

  /// File path to the cached cover image.
  final String path;

  /// Logical edge length in pixels, or `double.infinity` to fill the parent.
  final double size;

  /// Optional error builder forwarded to [Image.file].
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (size.isFinite) {
      final physicalEdge = (size * dpr).round();
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: physicalEdge,
        errorBuilder: errorBuilder,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final edge = constraints.maxWidth;
        final physicalEdge = edge.isFinite ? (edge * dpr).round() : 512;
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: physicalEdge,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}
