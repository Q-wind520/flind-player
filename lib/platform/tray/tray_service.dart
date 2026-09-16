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

import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart'
    show Locale, WidgetsBinding, WidgetsBindingObserver;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flind_player/app/l10n.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Keys identifying the tray context-menu entries.
const String trayMenuKeyWindowToggle = 'window.toggle';
const String trayMenuKeyPlayPause = 'playback.toggle';
const String trayMenuKeyPrevious = 'playback.previous';
const String trayMenuKeyNext = 'playback.next';
const String trayMenuKeyQuit = 'app.quit';

/// What a tray menu entry does when activated.
enum TrayMenuAction {
  showWindow,
  hideWindow,
  togglePlayPause,
  previous,
  next,
  quit,
}

/// The label for the play/pause entry, which follows playback state.
String trayPlayPauseLabel(AppLocalizations l10n, bool isPlaying) =>
    isPlaying ? l10n.trayPause : l10n.trayPlay;

/// Resolves a tray menu [key] to its [TrayMenuAction].
///
/// The window entry is a single toggle in the UI, so it resolves to
/// [TrayMenuAction.showWindow] or [TrayMenuAction.hideWindow] using the
/// window's current visibility. Returns `null` for unknown keys.
TrayMenuAction? trayMenuActionForKey(
  String key, {
  required bool isWindowVisible,
}) {
  switch (key) {
    case trayMenuKeyWindowToggle:
      return isWindowVisible
          ? TrayMenuAction.hideWindow
          : TrayMenuAction.showWindow;
    case trayMenuKeyPlayPause:
      return TrayMenuAction.togglePlayPause;
    case trayMenuKeyPrevious:
      return TrayMenuAction.previous;
    case trayMenuKeyNext:
      return TrayMenuAction.next;
    case trayMenuKeyQuit:
      return TrayMenuAction.quit;
    default:
      return null;
  }
}

/// Dispatches a resolved [action] to [playback] or the window callbacks.
///
/// This is the pure seam kept free of platform channels so it can be unit
/// tested without a desktop session.
Future<void> handleTrayMenuAction(
  TrayMenuAction action,
  PlaybackController playback, {
  required void Function() showWindow,
  required void Function() hideWindow,
  required void Function() quit,
}) async {
  switch (action) {
    case TrayMenuAction.showWindow:
      showWindow();
    case TrayMenuAction.hideWindow:
      hideWindow();
    case TrayMenuAction.togglePlayPause:
      await playback.togglePlayPause();
    case TrayMenuAction.previous:
      await playback.previous();
    case TrayMenuAction.next:
      await playback.next();
    case TrayMenuAction.quit:
      quit();
  }
}

/// Owns the desktop system tray and window-management integration.
///
/// Started only from `main.dart`, and only on desktop platforms. Integration
/// tests must not start it, so they never touch a real tray/window channel.
///
/// The desktop session (e.g. COSMIC on Wayland) may not display AppIndicator
/// icons at all; every platform call is guarded so that degrades gracefully
/// instead of crashing the app.
class TrayService with TrayListener, WindowListener, WidgetsBindingObserver {
  TrayService({required this.playback});

  final PlaybackController playback;
  StreamSubscription<PlaybackState>? _stateSubscription;
  bool _started = false;
  bool _quitting = false;
  String? _menuPlayPauseLabel;

  /// Brings up the window options, tray icon, context menu and listeners.
  ///
  /// Never throws; individual platform failures are logged and skipped.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    // main() already calls this before runApp (required by the Linux plugin);
    // calling it again is idempotent and keeps TrayService safe to start from
    // other entry points.
    final l10n = l10nForLocale(PlatformDispatcher.instance.locale);
    final windowOptions = WindowOptions(
      title: l10n.appName,
      // 360x480 is the smallest viewport every surface is verified to support
      // without layout overflow (see test/responsive_layout_test.dart).
      minimumSize: const Size(360, 480),
      center: true,
    );
    await _guard('ensureInitialized', windowManager.ensureInitialized);
    await _guard('waitUntilReadyToShow', () {
      return windowManager.waitUntilReadyToShow(windowOptions, () async {
        await _guard(
          'setPreventClose',
          () => windowManager.setPreventClose(true),
        );
        await _guard('show', windowManager.show);
      });
    });

    try {
      windowManager.addListener(this);
      trayManager.addListener(this);
      WidgetsBinding.instance.addObserver(this);
    } catch (error, stackTrace) {
      debugPrint('TrayService: addListener failed: $error\n$stackTrace');
    }

    await _guard('setIcon', _applyTrayIcon);
    // tray_manager's Linux plugin does not implement setToolTip.
    if (Platform.isWindows || Platform.isMacOS) {
      await _guard('setToolTip', () => trayManager.setToolTip(l10n.appName));
    }

    await _refreshMenu();

    _stateSubscription = playback.state.listen(
      (_) => unawaited(_refreshMenu()),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'TrayService: playback state stream error: $error\n$stackTrace',
        );
      },
    );
  }

  /// Tears down the tray icon and listeners.
  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    try {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      WidgetsBinding.instance.removeObserver(this);
    } catch (error, stackTrace) {
      debugPrint('TrayService: removeListener failed: $error\n$stackTrace');
    }
    await _guard('tray destroy', trayManager.destroy);
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_toggleWindowVisibility());
  }

  @override
  void onTrayIconRightMouseDown() {
    // Only the Windows backend forwards the right-click as an event and
    // expects the app to pop the menu itself; macOS and Linux backends show
    // the context menu natively.
    if (Platform.isWindows) {
      unawaited(
        _guard('popUpContextMenu', trayManager.popUpContextMenu),
      );
    }
  }

  @override
  void onWindowClose() {
    if (_quitting) {
      return;
    }
    unawaited(_guard('hide on close', windowManager.hide));
  }

  /// Re-applies the tray icon when the system switches light/dark mode.
  @override
  void didChangePlatformBrightness() {
    unawaited(_guard('setIcon (brightness)', _applyTrayIcon));
  }

  /// Rebuilds the tray menu in the new language when the system locale changes.
  @override
  void didChangeLocales(List<Locale>? locales) {
    _menuPlayPauseLabel = null;
    unawaited(_guard('refresh menu (locale)', _refreshMenu));
  }

  Future<void> _applyTrayIcon() async {
    await trayManager.setIcon(await _resolveTrayIcon());
  }

  /// A white glyph vanishes on a light panel (and a dark glyph on a dark one),
  /// so two monochrome variants ship and the one matching the panel brightness
  /// is chosen. `platformBrightness` follows the system theme, which on Linux
  /// is also what the panel follows.
  static String _trayIconAsset(Brightness brightness) =>
      brightness == Brightness.dark
      ? 'assets/tray/tray_icon_white.png' // dark panel -> white glyph
      : 'assets/tray/tray_icon_black.png'; // light panel -> dark glyph

  /// Resolves the bundled icon to the value [TrayManager.setIcon] expects on
  /// each platform.
  ///
  /// On Windows the backend loads the icon with `LoadImage`, which only
  /// understands `.ico` — a PNG path silently yields a NULL handle and a blank
  /// tray icon. The Dart-side `setIcon` resolves a relative path against
  /// `<exe>/data/flutter_assets/`, so the bundled multi-resolution `.ico` is
  /// referenced directly. On macOS/Linux the monochrome PNG matching the panel
  /// brightness is copied into app support and its filesystem path returned.
  Future<String> _resolveTrayIcon() async {
    if (Platform.isWindows) {
      return 'assets/tray/tray_icon.ico';
    }
    final asset = _trayIconAsset(
      PlatformDispatcher.instance.platformBrightness,
    );
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, p.basename(asset)));
    if (!await file.exists()) {
      final data = await rootBundle.load(asset);
      await file.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  Future<void> _refreshMenu() async {
    final l10n = l10nForLocale(PlatformDispatcher.instance.locale);
    final label = trayPlayPauseLabel(l10n, playback.currentState.isPlaying);
    // State ticks only advance position; only rebuild when the label flips.
    if (label == _menuPlayPauseLabel) {
      return;
    }
    _menuPlayPauseLabel = label;
    final menu = Menu(
      items: [
        MenuItem(
          key: trayMenuKeyWindowToggle,
          label: l10n.trayToggleWindow,
          onClick: (_) => _onMenuClick(trayMenuKeyWindowToggle),
        ),
        MenuItem(
          key: trayMenuKeyPlayPause,
          label: label,
          onClick: (_) => _onMenuClick(trayMenuKeyPlayPause),
        ),
        MenuItem(
          key: trayMenuKeyPrevious,
          label: l10n.trayPrevious,
          onClick: (_) => _onMenuClick(trayMenuKeyPrevious),
        ),
        MenuItem(
          key: trayMenuKeyNext,
          label: l10n.trayNext,
          onClick: (_) => _onMenuClick(trayMenuKeyNext),
        ),
        MenuItem.separator(),
        MenuItem(
          key: trayMenuKeyQuit,
          label: l10n.trayQuit,
          onClick: (_) => _onMenuClick(trayMenuKeyQuit),
        ),
      ],
    );
    await _guard('setContextMenu', () => trayManager.setContextMenu(menu));
  }

  void _onMenuClick(String key) {
    unawaited(_dispatchMenuKey(key));
  }

  Future<void> _dispatchMenuKey(String key) async {
    var visible = false;
    try {
      visible = await windowManager.isVisible();
    } catch (error, stackTrace) {
      debugPrint('TrayService: isVisible failed: $error\n$stackTrace');
    }
    final action = trayMenuActionForKey(key, isWindowVisible: visible);
    if (action == null) {
      return;
    }
    try {
      await handleTrayMenuAction(
        action,
        playback,
        showWindow: _showWindow,
        hideWindow: _hideWindow,
        quit: _quit,
      );
    } catch (error, stackTrace) {
      debugPrint('TrayService: menu action "$key" failed: $error\n$stackTrace');
    }
  }

  void _showWindow() => unawaited(_guard('show', windowManager.show));

  void _hideWindow() => unawaited(_guard('hide', windowManager.hide));

  void _quit() {
    _quitting = true;
    unawaited(_guard('destroy', windowManager.destroy));
  }

  Future<void> _toggleWindowVisibility() async {
    try {
      if (await windowManager.isVisible()) {
        await windowManager.hide();
      } else {
        await windowManager.show();
      }
    } catch (error, stackTrace) {
      debugPrint('TrayService: toggle window failed: $error\n$stackTrace');
    }
  }

  Future<void> _guard(String operation, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('TrayService: $operation failed: $error\n$stackTrace');
    }
  }
}
