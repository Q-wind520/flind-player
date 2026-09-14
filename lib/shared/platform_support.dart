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

import 'package:flutter/foundation.dart';

/// Whether this platform offers the local music library (scan roots, folder
/// add / rescan, file import).
///
/// iOS is sandboxed and exposes no user-selectable filesystem roots, so the
/// local library is unavailable there. Uses [defaultTargetPlatform] rather than
/// `dart:io`'s `Platform` so widget tests can override it with
/// `debugDefaultTargetPlatformOverride`.
bool get supportsLocalLibrary =>
    !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;
