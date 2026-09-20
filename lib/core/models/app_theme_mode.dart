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

/// The user's choice of app appearance.
///
/// Stored by name in preferences; an unknown or missing value falls back to
/// [AppThemeMode.system].
enum AppThemeMode {
  /// Follow the operating system's brightness. The default.
  system,

  /// Always use the light theme.
  light,

  /// Always use the dark theme.
  dark,
}
