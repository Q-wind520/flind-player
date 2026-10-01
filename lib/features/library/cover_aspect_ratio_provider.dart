// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/shared/cover_image.dart';

/// Resolves the width/height ratio of a cover (`path` or `http` URL).
///
/// Reuses Flutter's image cache through the matching [ImageProvider], so the
/// waterfall card's own image load is not duplicated. Falls back to `1.0` for
/// a missing or undecodable image and caches the resolved value per key.
final coverAspectRatioProvider = FutureProvider.family<double, String>((
  ref,
  source,
) async {
  if (source.isEmpty) return 1.0;
  final ImageProvider<Object> provider = source.startsWith('http')
      ? NetworkImage(source, headers: kCoverImageHeaders)
      : FileImage(File(source));

  final completer = Completer<double>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) {
        final height = info.image.height;
        completer.complete(height == 0 ? 1.0 : info.image.width / height);
      }
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) completer.complete(1.0);
    },
  );
  stream.addListener(listener);
  ref.onDispose(() => stream.removeListener(listener));
  return completer.future;
});
