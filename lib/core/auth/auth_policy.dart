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

/// Which data paths of a source need a signed-in account.
///
/// This is deliberately separate from the driver's protocol: NetEase, for
/// example, may support login for VIP audio while its lyrics remain readable
/// anonymously. The UI asks this policy before offering a login action.
class AuthSourcePolicy {
  const AuthSourcePolicy({
    this.lyricsRequireLogin = false,
    this.highQualityRequiresLogin = false,
  });

  final bool lyricsRequireLogin;
  final bool highQualityRequiresLogin;
}
