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

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';
import 'package:flind_player/data/services/cover_saver.dart';
import 'package:flind_player/l10n/app_localizations.dart';

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

  /// True while a save is in flight, so repeated taps are ignored.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _original = ref.read(coverOriginalResolverProvider).resolve(widget.track);
  }

  Future<void> _save(CoverOriginal original) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
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
    } finally {
      if (mounted) setState(() => _saving = false);
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.imageNotSupported,
              size: 56,
              color: Colors.white70,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.coverOriginalUnavailable,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.close),
            // Fixed light-on-dark chrome: the viewer sits on a dark scrim in
            // both themes, so theme-semantic colours can vanish.
            color: Colors.white,
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: (original == null || loading || _saving)
                ? null
                : () => _save(original),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(AppIcons.download),
            label: Text(l10n.downloadCover),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
