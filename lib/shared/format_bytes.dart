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

/// Formats a byte count using binary units (`KiB`/`MiB`/`GiB`).
///
/// Bytes and kilobytes are whole numbers; megabytes and gigabytes carry one
/// decimal place, which is dropped when it would be a trailing `.0`. Examples:
/// `0 B`, `512 B`, `512 KB`, `1 MB`, `1.5 MB`, `2 GB`.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';

  const int kb = 1024;
  const int mb = kb * 1024;
  const int gb = mb * 1024;

  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${bytes ~/ kb} KB';
  if (bytes < gb) return '${_oneDecimal(bytes / mb)} MB';
  return '${_oneDecimal(bytes / gb)} GB';
}

/// Formats [value] with one decimal, omitting a trailing `.0`.
String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Formats a byte count as mebibytes, always with an explicit `MB` suffix.
///
/// The cache cap is edited and displayed in a single unit (MB), so the settings
/// screen needs a stable unit rather than [formatBytes]'s KB/MB/GB scaling.
/// Examples: `0 MB`, `300 MB`, `1024 MB`, `12.5 MB`.
String formatMegabytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const int mb = 1024 * 1024;
  return '${_oneDecimal(bytes / mb)} MB';
}
