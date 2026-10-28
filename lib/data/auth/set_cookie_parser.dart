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

/// Parses a plain `Cookie` request header into a name/value map.
///
/// Empty values (`deviceId=`) are preserved because some NetEase endpoints
/// treat their presence as part of the client fingerprint.
Map<String, String> parseCookieHeader(String raw) {
  final cookies = <String, String>{};
  for (final part in raw.split(';')) {
    final separator = part.indexOf('=');
    if (separator <= 0) continue;
    final name = part.substring(0, separator).trim();
    if (name.isEmpty) continue;
    cookies[name] = part.substring(separator + 1).trim();
  }
  return cookies;
}

/// Extracts `name=value` pairs from `Set-Cookie` response headers.
///
/// Attributes (`Path`, `Domain`, `Expires`, `HttpOnly`, ...) are ignored. A
/// header may legally be comma-joined by an HTTP stack; repeated names keep the
/// last value, matching the order in which a browser would apply them.
Map<String, String> parseSetCookieHeaders(Iterable<String> headers) {
  final cookies = <String, String>{};
  for (final header in headers) {
    // Most HTTP stacks expose one entry per cookie, but a comma-joined header
    // is legal. Only split before a `name=` token so an `Expires=Wed, 21 Oct`
    // attribute survives intact.
    for (final part in header.split(RegExp(r',\s*(?=[^;,=]+=)'))) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;

      final name = part.substring(0, separator).trim();
      if (name.isEmpty) continue;

      final rawValue = part.substring(separator + 1);
      final end = rawValue.indexOf(';');
      final value = (end == -1 ? rawValue : rawValue.substring(0, end)).trim();
      if (value.isEmpty) continue;

      cookies[name] = value;
    }
  }
  return cookies;
}
