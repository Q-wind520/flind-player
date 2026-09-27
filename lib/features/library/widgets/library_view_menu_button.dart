// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/features/library/library_view_provider.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// An AppBar button that switches the view for [scope].
class LibraryViewMenuButton extends ConsumerStatefulWidget {
  const LibraryViewMenuButton({
    super.key,
    required this.scope,
    this.icon = Icons.grid_view_rounded,
  });

  final LibraryViewScope scope;
  final IconData icon;

  @override
  ConsumerState<LibraryViewMenuButton> createState() =>
      _LibraryViewMenuButtonState();
}

class _LibraryViewMenuButtonState extends ConsumerState<LibraryViewMenuButton> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final views =
        ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults;
    final current = views.viewOf(widget.scope);

    return MenuAnchor(
      controller: _controller,
      menuChildren: <Widget>[
        for (final view in widget.scope.allowedViews)
          MenuItemButton(
            leadingIcon: view == current ? const Icon(Icons.check) : null,
            onPressed: () {
              _controller.close();
              ref
                  .read(libraryViewsProvider.notifier)
                  .setView(widget.scope, view);
            },
            child: Text(_viewLabel(l10n, view)),
          ),
      ],
      builder: (context, controller, child) => IconButton(
        key: const Key('library_view_menu'),
        tooltip: l10n.menuView,
        icon: Icon(widget.icon),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The display label for a [LibraryView] option.
String _viewLabel(AppLocalizations l10n, LibraryView view) => switch (view) {
  LibraryView.showcase => l10n.viewShowcase,
  LibraryView.list => l10n.viewList,
  LibraryView.waterfall => l10n.viewWaterfall,
};
