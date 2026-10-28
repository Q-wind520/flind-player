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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/bilibili/bili_models.dart';
import 'package:flind_player/data/sources/bilibili/bili_quality.dart';

DashAudioDto _audio({
  required int id,
  required int bandwidth,
  String mimeType = 'audio/mp4',
  String codecs = 'mp4a.40.2',
}) {
  return DashAudioDto(
    id: id,
    baseUrl: 'https://example.com/$id.m4s',
    backupUrl: const <String>[],
    bandwidth: bandwidth,
    mimeType: mimeType,
    codecs: codecs,
    size: 1,
  );
}

void main() {
  test('prefers the highest-bandwidth AAC entry over FLAC', () {
    final selected = selectBiliAudio(<DashAudioDto>[
      _audio(id: 30216, bandwidth: 64_000),
      _audio(id: 30280, bandwidth: 192_000),
      _audio(
        id: 30251,
        bandwidth: 1_400_000,
        mimeType: 'audio/flac',
        codecs: 'fLaC',
      ),
    ]);

    expect(selected?.id, 30280);
  });

  test('a signed-in caller may use the highest compatible FLAC tier', () {
    final selected = selectBiliAudio(<DashAudioDto>[
      _audio(id: 30280, bandwidth: 192_000),
      _audio(
        id: 30251,
        bandwidth: 1_400_000,
        mimeType: 'audio/flac',
        codecs: 'fLaC',
      ),
      _audio(
        id: 30250,
        bandwidth: 448_000,
        mimeType: 'audio/mp4',
        codecs: 'ec-3',
      ),
    ], includeFlac: true);

    expect(selected?.id, 30251);
  });

  test('falls back to the highest bandwidth when no AAC exists', () {
    final selected = selectBiliAudio(<DashAudioDto>[
      _audio(
        id: 30250,
        bandwidth: 448_000,
        mimeType: 'audio/mp4',
        codecs: 'ec-3',
      ),
      _audio(
        id: 30251,
        bandwidth: 1_400_000,
        mimeType: 'audio/flac',
        codecs: 'fLaC',
      ),
    ]);

    expect(selected?.id, 30251);
  });

  test('returns null for an empty list', () {
    expect(selectBiliAudio(const <DashAudioDto>[]), isNull);
  });
}
