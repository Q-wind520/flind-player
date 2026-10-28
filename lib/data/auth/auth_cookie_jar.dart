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

/// In-memory cookie jars, one map per source.
///
/// Sources read the current jar for every request instead of holding a
/// snapshot, so logging in or out takes effect without rebuilding providers.
/// The jar is deliberately not persisted: [AuthSessionStore] owns credentials
/// at rest and hydrates this jar on startup.
class AuthCookieJar {
  final Map<String, Map<String, String>> _bySource =
      <String, Map<String, String>>{};

  /// Replaces every cookie for [sourceId].
  void replace(String sourceId, Map<String, String> cookies) {
    if (cookies.isEmpty) {
      _bySource.remove(sourceId);
      return;
    }
    _bySource[sourceId] = Map<String, String>.unmodifiable(cookies);
  }

  /// Adds/overwrites the given cookies without dropping existing names.
  void merge(String sourceId, Map<String, String> cookies) {
    if (cookies.isEmpty) return;
    final merged = <String, String>{
      ..._bySource[sourceId] ?? const {},
      ...cookies,
    };
    _bySource[sourceId] = Map<String, String>.unmodifiable(merged);
  }

  /// Removes all cookies for [sourceId].
  void clear(String sourceId) {
    _bySource.remove(sourceId);
  }

  /// Current cookies for [sourceId], or an empty map.
  Map<String, String> cookiesFor(String sourceId) =>
      _bySource[sourceId] ?? const <String, String>{};

  /// A ready-to-send `Cookie` header, or `null` when the jar is empty.
  String? cookieHeader(String sourceId) {
    final cookies = _bySource[sourceId];
    if (cookies == null || cookies.isEmpty) return null;
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}
