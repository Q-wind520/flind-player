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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/sources/bilibili/bili_api.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/bilibili/bili_source.dart';
import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/bilibili/risk_control.dart';
import 'package:flind_player/data/sources/bilibili/wbi_signer.dart';

/// Shared, configured Dio wrapper for `api.bilibili.com`.
final biliClientProvider = Provider<BiliClient>((ref) => BiliClient());

/// Serializes and paces all Bilibili requests.
final biliRateLimiterProvider = Provider<RateLimiter>((ref) => RateLimiter());

/// WBI signer, wired to fetch its daily keys through the rate-limited client.
///
/// The `nav` endpoint answers `code: -101` when anonymous but still returns the
/// keys, hence the allow-list.
final biliWbiSignerProvider = Provider<WbiSigner>((ref) {
  final client = ref.watch(biliClientProvider);
  final limiter = ref.watch(biliRateLimiterProvider);
  return WbiSigner(
    fetchKeys: () async {
      final json = await limiter.run(
        () => client.getJson(
          '/x/web-interface/nav',
          allowCodes: const <int>{-101},
        ),
      );
      return WbiSigner.parseNavKeys(json);
    },
  );
});

/// Anonymous device fingerprint (`buvid3`/`buvid4`) provider.
final riskControlProvider = Provider<RiskControl>(
  (ref) => RiskControl(client: ref.watch(biliClientProvider)),
);

/// Typed Bilibili endpoint client.
final biliApiProvider = Provider<BiliApi>(
  (ref) => BiliApi(
    client: ref.watch(biliClientProvider),
    signer: ref.watch(biliWbiSignerProvider),
    rateLimiter: ref.watch(biliRateLimiterProvider),
    riskControl: ref.watch(riskControlProvider),
  ),
);

/// Bilibili as a searchable, directly streamable [BiliSource].
final biliSourceProvider = Provider<BiliSource>(
  (ref) => BiliSource(api: ref.watch(biliApiProvider)),
);
