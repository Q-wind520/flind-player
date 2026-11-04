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
import 'package:flind_player/shared/app_surface.dart';

/// The shared full-page shell: neutral page surface, safe area, a centred
/// max-width column, and a fixed page header above the scrolling body.
///
/// Keeping this in one widget stops individual screens from inventing their
/// own page width, padding and SafeArea combinations.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.header,
    required this.body,
    this.width = AppContentKind.standard,
    this.resizeToAvoidBottomInset,
  });

  /// Usually an [AppPageHeader].
  final Widget header;

  /// The page body, normally a scrollable.
  final Widget body;

  /// Width bucket for wide windows.
  final AppContentKind width;

  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppContentWidth.of(width)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
