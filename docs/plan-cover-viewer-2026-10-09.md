# Cover Viewer & Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player cover open a full-screen original-image viewer (right-click / long-press) that can download the full-resolution cover to the album (mobile) or a local file (desktop).

**Architecture:** A full-screen `CoverViewerScreen` route resolves the original via an injectable `CoverOriginalResolver` (online: fetch `coverUrl` bytes through the existing `CoverDownloader`; local: read the verbatim-artwork `coverPath`; else null) and saves via an injectable `CoverSaver` seam (`AlbumCoverSaver` on mobile using `gal`, `FileCoverSaver` on desktop using `file_picker`). The player cover gains a `GestureDetector` (secondary tap / long press) that pushes the viewer.

**Tech Stack:** Flutter (Material 3), Riverpod, `gal` (new), `file_picker`, `dio`, `flutter_test`.

**Spec:** `docs/spec-cover-viewer-2026-10-09.md`

## Global Constraints

- The online `coverUrl` is already the un-suffixed original; the local `coverPath` is the verbatim embedded artwork — do **not** add an audio re-extraction path.
- **Only one new dependency: `gal`** (mobile album path). Desktop uses the existing `file_picker`; do not add anything else.
- Touch only the **PlayerScreen cover** entry; list and mini-player covers are unchanged.
- Desktop = Linux/Windows/macOS → `FileCoverSaver`; mobile = Android/iOS → `AlbumCoverSaver`.
- Keep `flutter analyze` clean and the whole suite green. Baseline before this plan: **869 passed**.
- Commit locally on `master` only; **do not push**.

## Review Focus

The spec says what the software must do but not every input; these failure modes are the most likely to bite a user, each with a test in the owning task.

1. **A track with no cover at all** (URL and path both null) must not crash: the resolver returns `null`, the viewer shows "无法获取原图" and disables download. → Tasks 1, 3.
2. **The remote fetch fails** (offline / 403 / timeout / oversized) must fall back to the local cached file, and only then to the error state. → Task 1.
3. **An oversized original** must not OOM: the existing `CoverDownloader` caps at 8 MB and returns `null`, which the resolver treats as a miss. → Task 1.
4. **An illegal file name** (title/artist containing `/ : * ? " < > |`) must be sanitized so the save dialog does not fail. → Task 1.
5. **A cancelled save** (user dismisses the dialog) must stay silent — no error SnackBar, no crash. → Tasks 2, 3.
6. **A very large image** must still render; decode memory is bounded by using the bytes as-is and is flagged as a risk. → Task 3 (smoke test), §Risks.

---

### Task 1: `CoverOriginal` + `CoverOriginalResolver` + provider

**Files:**
- Create: `lib/data/services/cover_original_resolver.dart`
- Modify: `lib/data/providers/cover_providers.dart`
- Test: `test/cover_original_resolver_test.dart` (create)

**Interfaces:**
- Consumes: `CoverDownloader.download` (existing), `Track`.
- Produces:
  - `CoverOriginal({required Uint8List bytes, required String mimeType, required String suggestedName})`.
  - `CoverOriginalResolver({required Future<Uint8List?> Function(String) fetchRemote, required Future<Uint8List?> Function(String) readLocal})` with `Future<CoverOriginal?> resolve(Track track)`.
  - `String sniffImageMime(Uint8List)`, `String suggestedCoverName(Track, String mimeType)`, `Future<Uint8List?> readFileBytes(String)`.
  - `coverOriginalResolverProvider` — used by Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/cover_original_resolver_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';

final _jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
final _png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Track _track({String? coverUrl, String? coverPath, String? artist}) => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Title',
  artist: artist,
  coverUrl: coverUrl,
  coverPath: coverPath,
);

void main() {
  test('fetches the original from the remote url first', () async {
    final resolver = CoverOriginalResolver(
      fetchRemote: (url) async => _png,
      readLocal: (path) async => _jpeg,
    );

    final original = await resolver.resolve(
      _track(coverUrl: 'https://x/y.jpg', coverPath: '/c/a.jpg'),
    );

    expect(original, isNotNull);
    expect(original!.bytes, _png);
    expect(original.mimeType, 'image/png');
    expect(original.suggestedName, 'Title.png');
  });

  test('falls back to the local file when the remote fetch fails', () async {
    final resolver = CoverOriginalResolver(
      fetchRemote: (url) async => null,
      readLocal: (path) async => _jpeg,
    );

    final original = await resolver.resolve(
      _track(coverUrl: 'https://x/y.jpg', coverPath: '/c/a.jpg'),
    );

    expect(original, isNotNull);
    expect(original!.mimeType, 'image/jpeg');
  });

  test('returns null when there is no cover at all', () async {
    final resolver = CoverOriginalResolver(
      fetchRemote: (url) async => _jpeg,
      readLocal: (path) async => _jpeg,
    );

    expect(await resolver.resolve(_track()), isNull);
  });

  test('sniffs common image types and defaults to jpeg', () {
    expect(sniffImageMime(_png), 'image/png');
    expect(sniffImageMime(_jpeg), 'image/jpeg');
    expect(sniffImageMime(Uint8List.fromList(<int>[1, 2, 3])), 'image/jpeg');
  });

  test('builds a filesystem-safe suggested name', () {
    final name = suggestedCoverName(
      _track(artist: 'A/B:C*D'),
      'image/jpeg',
    );
    expect(name, 'A_B_C_D - Title.jpg');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/cover_original_resolver_test.dart`
Expected: FAIL — `CoverOriginalResolver` etc. are undefined.

- [ ] **Step 3: Implement the resolver**

Create `lib/data/services/cover_original_resolver.dart`:

```dart
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
import 'dart:typed_data';

import 'package:flind_player/core/models/track.dart';

/// A full-resolution cover image resolved for the original-image viewer.
class CoverOriginal {
  const CoverOriginal({
    required this.bytes,
    required this.mimeType,
    required this.suggestedName,
  });

  /// The raw image bytes.
  final Uint8List bytes;

  /// The image MIME type (sniffed from [bytes]).
  final String mimeType;

  /// A filesystem-safe file name suggested for saving.
  final String suggestedName;
}

/// Resolves a track's full-resolution cover for the viewer.
///
/// The stored `coverUrl` is already the un-suffixed original, and the local
/// `coverPath` is the verbatim embedded artwork, so both are originals. The
/// URL is preferred; a fetch that fails (offline, 403, timeout, oversized)
/// falls back to the local file; when neither yields bytes the result is null.
class CoverOriginalResolver {
  const CoverOriginalResolver({
    required this.fetchRemote,
    required this.readLocal,
  });

  /// Fetches the bytes at a remote URL, or null on any failure.
  final Future<Uint8List?> Function(String url) fetchRemote;

  /// Reads the bytes at a local path, or null on any failure.
  final Future<Uint8List?> Function(String path) readLocal;

  Future<CoverOriginal?> resolve(Track track) async {
    final url = track.coverUrl;
    if (url != null && url.isNotEmpty) {
      final bytes = await fetchRemote(url);
      if (bytes != null && bytes.isNotEmpty) return _wrap(track, bytes);
    }

    final path = track.coverPath;
    if (path != null && path.isNotEmpty) {
      final bytes = await readLocal(path);
      if (bytes != null && bytes.isNotEmpty) return _wrap(track, bytes);
    }

    return null;
  }

  CoverOriginal _wrap(Track track, Uint8List bytes) {
    final mime = sniffImageMime(bytes);
    return CoverOriginal(
      bytes: bytes,
      mimeType: mime,
      suggestedName: suggestedCoverName(track, mime),
    );
  }
}

/// Sniffs common image MIME types from [bytes]; defaults to JPEG.
String sniffImageMime(Uint8List bytes) {
  if (bytes.length >= 12) {
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
  }
  return 'image/jpeg';
}

/// A filesystem-safe suggested file name for [track]'s cover.
String suggestedCoverName(Track track, String mimeType) {
  final ext = switch (mimeType) {
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  final artist = track.artist?.trim() ?? '';
  final base = <String>[artist, track.title].where((s) => s.isNotEmpty).join(' - ');
  final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return '${safe.isEmpty ? 'cover' : safe}.$ext';
}

/// Reads a file's bytes, or null when it is missing or unreadable.
Future<Uint8List?> readFileBytes(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
```

- [ ] **Step 4: Add the provider**

In `lib/data/providers/cover_providers.dart`, add the import and provider:

```dart
import 'package:flind_player/data/services/cover_original_resolver.dart';
```

```dart
/// Resolves a track's full-resolution cover for the original-image viewer:
/// the remote URL first (via [CoverDownloader]), then the local artwork file.
final coverOriginalResolverProvider = Provider<CoverOriginalResolver>((ref) {
  final downloader = ref.watch(coverDownloaderProvider);
  return CoverOriginalResolver(
    fetchRemote: downloader.download,
    readLocal: readFileBytes,
  );
});
```

- [ ] **Step 5: Run the test and the analyzer**

Run: `flutter test test/cover_original_resolver_test.dart && flutter analyze`
Expected: PASS (5 tests), no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/data/services/cover_original_resolver.dart lib/data/providers/cover_providers.dart test/cover_original_resolver_test.dart
git commit -m "feat: resolve a track's full-resolution cover"
```

---

### Task 2: `CoverSaver` seam + `gal`

**Files:**
- Modify: `pubspec.yaml` (add `gal`)
- Create: `lib/data/services/cover_saver.dart`
- Modify: `lib/data/providers/cover_providers.dart`
- Test: `test/cover_saver_test.dart` (create)

**Interfaces:**
- Consumes: `CoverOriginal` (Task 1).
- Produces:
  - `enum CoverSaveResult { saved, cancelled, failed }`.
  - `abstract class CoverSaver { Future<CoverSaveResult> save(CoverOriginal original); }`.
  - `AlbumCoverSaver` (mobile), `FileCoverSaver` (desktop).
  - `coverSaverProvider` — used by Task 3.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add gal`
Expected: `gal` is added to `pubspec.yaml` and resolved.

- [ ] **Step 2: Write the failing test**

Create `test/cover_saver_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/services/cover_saver.dart';

void main() {
  test('selects the album saver on mobile', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(coverSaverProvider), isA<AlbumCoverSaver>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('selects the file saver on desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(coverSaverProvider), isA<FileCoverSaver>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/cover_saver_test.dart`
Expected: FAIL — `CoverSaver`/`coverSaverProvider` are undefined.

- [ ] **Step 4: Implement the seam**

Create `lib/data/services/cover_saver.dart`:

```dart
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

import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';

import 'package:flind_player/data/services/cover_original_resolver.dart';

/// The outcome of saving a cover image.
enum CoverSaveResult { saved, cancelled, failed }

/// Persists a resolved cover to the platform's destination.
abstract class CoverSaver {
  /// Saves [original]; never throws — failures become [CoverSaveResult.failed].
  Future<CoverSaveResult> save(CoverOriginal original);
}

/// Saves into the system photo album (Android / iOS).
class AlbumCoverSaver implements CoverSaver {
  const AlbumCoverSaver();

  @override
  Future<CoverSaveResult> save(CoverOriginal original) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return CoverSaveResult.failed;
      }
      await Gal.putImageBytes(original.bytes, name: original.suggestedName);
      return CoverSaveResult.saved;
    } catch (_) {
      return CoverSaveResult.failed;
    }
  }
}

/// Saves through the native file-save dialog (desktop).
///
/// [FilePicker.saveFile] writes [CoverOriginal.bytes] to the chosen path and
/// returns its URI, or null when the user cancels.
class FileCoverSaver implements CoverSaver {
  const FileCoverSaver();

  @override
  Future<CoverSaveResult> save(CoverOriginal original) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: original.suggestedName,
        bytes: original.bytes,
        mimeType: original.mimeType,
      );
      return uri == null ? CoverSaveResult.cancelled : CoverSaveResult.saved;
    } catch (_) {
      return CoverSaveResult.failed;
    }
  }
}
```

Then in `lib/data/providers/cover_providers.dart`, add the import and provider:

```dart
import 'package:flind_player/data/services/cover_saver.dart';
```

```dart
/// The platform's cover saver: the photo album on mobile, a file dialog on
/// desktop.
final coverSaverProvider = Provider<CoverSaver>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => const AlbumCoverSaver(),
    _ => const FileCoverSaver(),
  };
});
```

- [ ] **Step 5: Run the test and the analyzer**

Run: `flutter test test/cover_saver_test.dart && flutter analyze`
Expected: PASS (2 tests), no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/services/cover_saver.dart lib/data/providers/cover_providers.dart test/cover_saver_test.dart
git commit -m "feat: add a platform cover saver (album or file)"
```

---

### Task 3: `CoverViewerScreen` + l10n

**Files:**
- Create: `lib/features/player/cover_viewer_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/cover_viewer_screen_test.dart` (create)

**Interfaces:**
- Consumes: `coverOriginalResolverProvider` (Task 1), `coverSaverProvider`, `CoverSaveResult` (Task 2), `Track`.
- Produces: `CoverViewerScreen({Key? key, required Track track})`, `Route<void> coverViewerRoute(Track track)` — used by Task 4.

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_zh.arb`, add before the final `}`:

```json
  "downloadCover": "下载封面图",
  "coverSaved": "已保存封面图",
  "coverSaveFailed": "保存封面图失败",
  "coverOriginalUnavailable": "无法获取原图"
```

In `lib/l10n/app_en.arb`, add before the final `}`:

```json
  "downloadCover": "Download cover",
  "coverSaved": "Cover saved",
  "coverSaveFailed": "Failed to save cover",
  "coverOriginalUnavailable": "Original image unavailable"
```

Then run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/cover_viewer_screen_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';
import 'package:flind_player/data/services/cover_saver.dart';
import 'package:flind_player/features/player/cover_viewer_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';

import 'support/l10n.dart';

/// A valid 1×1 PNG so the viewer's `Image.memory` decodes without an error.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Title',
);

class _FakeSaver implements CoverSaver {
  _FakeSaver(this.result);
  final CoverSaveResult result;
  int calls = 0;
  @override
  Future<CoverSaveResult> save(CoverOriginal original) async {
    calls++;
    return result;
  }
}

Widget _app({
  required CoverOriginalResolver resolver,
  required CoverSaver saver,
}) => ProviderScope(
  overrides: [
    coverOriginalResolverProvider.overrideWithValue(resolver),
    coverSaverProvider.overrideWithValue(saver),
  ],
  child: localizedApp(CoverViewerScreen(track: _track())),
);

void main() {
  testWidgets('shows the original and saves it', (tester) async {
    final saver = _FakeSaver(CoverSaveResult.saved);
    await tester.pumpWidget(
      _app(
        resolver: CoverOriginalResolver(
          fetchRemote: (url) async => _png,
          readLocal: (path) async => _png,
        ),
        saver: saver,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);

    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.tap(find.text(l10n.downloadCover));
    await tester.pumpAndSettle();

    expect(saver.calls, 1);
    expect(find.text(l10n.coverSaved), findsOneWidget);
  });

  testWidgets('shows an unavailable state and disables download', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        resolver: CoverOriginalResolver(
          fetchRemote: (url) async => null,
          readLocal: (path) async => null,
        ),
        saver: _FakeSaver(CoverSaveResult.saved),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(find.text(l10n.coverOriginalUnavailable), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.downloadCover),
    );
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/cover_viewer_screen_test.dart`
Expected: FAIL — `CoverViewerScreen` is undefined.

- [ ] **Step 4: Implement the viewer**

Create `lib/features/player/cover_viewer_screen.dart`:

```dart
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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';
import 'package:flind_player/data/services/cover_saver.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';

/// A fade route onto [CoverViewerScreen].
Route<void> coverViewerRoute(Track track) => PageRouteBuilder<void>(
  transitionDuration: AppMotion.standard,
  reverseTransitionDuration: AppMotion.standard,
  pageBuilder: (context, animation, secondaryAnimation) =>
      CoverViewerScreen(track: track),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
);

/// Full-screen original-cover viewer with a download action.
class CoverViewerScreen extends ConsumerStatefulWidget {
  const CoverViewerScreen({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<CoverViewerScreen> createState() => _CoverViewerScreenState();
}

class _CoverViewerScreenState extends ConsumerState<CoverViewerScreen> {
  late final Future<CoverOriginal?> _original;

  @override
  void initState() {
    super.initState();
    _original = ref.read(coverOriginalResolverProvider).resolve(widget.track);
  }

  Future<void> _save(CoverOriginal original) async {
    final result = await ref.read(coverSaverProvider).save(original);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case CoverSaveResult.saved:
        messenger.showSnackBar(SnackBar(content: Text(l10n.coverSaved)));
      case CoverSaveResult.cancelled:
        break;
      case CoverSaveResult.failed:
        messenger.showSnackBar(SnackBar(content: Text(l10n.coverSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.scrim,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: SafeArea(
          child: FutureBuilder<CoverOriginal?>(
            future: _original,
            builder: (context, snapshot) {
              final original = snapshot.data;
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              return Stack(
                children: [
                  Positioned.fill(child: _body(context, original, loading)),
                  _topBar(context, l10n, original, loading),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CoverOriginal? original, bool loading) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (original == null) {
      final l10n = AppLocalizations.of(context);
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.coverOriginalUnavailable,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 6,
        child: GestureDetector(
          // Absorb taps on the image so only the surrounding scrim closes.
          onTap: () {},
          child: Image.memory(original.bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _topBar(
    BuildContext context,
    AppLocalizations l10n,
    CoverOriginal? original,
    bool loading,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            color: scheme.onSurface,
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: (original == null || loading)
                ? null
                : () => _save(original),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.downloadCover),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests and the analyzer**

Run: `flutter test test/cover_viewer_screen_test.dart && flutter analyze`
Expected: PASS (2 tests), no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/cover_viewer_screen.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb test/cover_viewer_screen_test.dart
git commit -m "feat: add the full-screen cover viewer"
```

---

### Task 4: Player cover entry gesture

**Files:**
- Modify: `lib/features/player/player_screen.dart` (`_PlayerCover`)
- Test: `test/cover_viewer_entry_test.dart` (create)

**Interfaces:**
- Consumes: `coverViewerRoute` (Task 3).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Create `test/cover_viewer_entry_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';
import 'package:flind_player/features/player/cover_viewer_screen.dart';
import 'package:flind_player/features/player/player_screen.dart';
import 'package:flind_player/shared/cover_hero.dart';

import 'support/l10n.dart';

class _FakeFavoritesRepository implements FavoritesRepository {
  @override
  Stream<List<Track>> watchFavorites() => Stream.value(const <Track>[]);
  @override
  Future<List<Track>> allFavorites() async => const <Track>[];
  @override
  Future<bool> isFavorite(String uri) async => false;
  @override
  Future<void> addFavorite(Track track) async {}
  @override
  Future<void> removeFavorite(String uri) async {}
  @override
  Future<bool> toggleFavorite(Track track) async => false;
}

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Now Playing',
);

Widget _app(PlaybackState state) => ProviderScope(
  overrides: [
    playbackStateProvider.overrideWith((ref) => Stream.value(state)),
    favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
    coverOriginalResolverProvider.overrideWithValue(
      CoverOriginalResolver(
        fetchRemote: (url) async => null,
        readLocal: (path) async => null,
      ),
    ),
  ],
  child: localizedApp(const PlayerScreen()),
);

void main() {
  testWidgets('long-pressing the cover opens the viewer', (tester) async {
    final state = PlaybackState(
      isPlaying: true,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track(),
    );

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(CoverHero));
    await tester.pumpAndSettle();

    expect(find.byType(CoverViewerScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/cover_viewer_entry_test.dart`
Expected: FAIL — the cover has no long-press handler, so the viewer never opens.

- [ ] **Step 3: Implement the entry gesture**

In `lib/features/player/player_screen.dart`, add the import:

```dart
import 'package:flind_player/features/player/cover_viewer_screen.dart';
```

Replace `_PlayerCover.build`'s `return CoverHero(...)` with a gesture wrapper:

```dart
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Desktop: right-click. Touch: long-press.
      onSecondaryTap: () => Navigator.of(context).push(coverViewerRoute(track)),
      onLongPress: () => Navigator.of(context).push(coverViewerRoute(track)),
      child: CoverHero(
        uri: track.uri,
        coverPath: coverPath,
        coverUrl: coverUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            width: size,
            height: size,
            color: scheme.surfaceContainerHighest,
            child: hasCover
                ? CoverImage(
                    path: coverPath,
                    url: coverUrl,
                    size: size,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(scheme),
                  )
                : _placeholder(scheme),
          ),
        ),
      ),
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/cover_viewer_entry_test.dart test/favorites_ui_test.dart`
Expected: PASS — including the existing player-cover tests.

- [ ] **Step 5: Run the analyzer and the full suite**

Run: `flutter analyze && flutter test`
Expected: analyzer clean; the whole suite passes (baseline 869 + the new tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/player_screen.dart test/cover_viewer_entry_test.dart
git commit -m "feat: open the cover viewer from the player cover"
```

---

## Final Verification

- [ ] `flutter analyze` — no issues.
- [ ] `flutter test` — all tests pass.
- [ ] Manual eyeball (required; not automatable): on desktop, right-click a player cover and open the viewer, zoom/pan, and use "下载封面图" (a save dialog appears and writes the file); Esc/X/back close it. On a mobile device, long-press the cover and confirm the download lands in the photo album and that denying permission reports a failure without crashing.

## Self-Review Notes

- **Spec coverage:** §3.1 entry → Task 4; §3.2 resolver → Task 1; §3.3 viewer → Task 3; §3.4 saver → Task 2; §3.5 dependency → Task 2; §3.6 edge behaviour → Tasks 1–3.
- **Interfaces:** `CoverOriginal.bytes/mimeType/suggestedName`, `CoverOriginalResolver.fetchRemote/readLocal/resolve`, `CoverSaver.save`, `coverOriginalResolverProvider`, `coverSaverProvider`, `coverViewerRoute`, `CoverViewerScreen.track` are named identically across producers and consumers.
- **Known gap:** the album/file plugin calls themselves are not unit-tested (platform channels); the seam selection and the viewer's use of the seam are.
