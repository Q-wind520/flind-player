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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

/// The app's single icon vocabulary.
///
/// All glyphs come from Lucide's regular (line) set, so controls keep one
/// stroke weight and one visual language. Names are semantic rather than tied
/// to a vendor, which keeps call sites readable and makes a future icon-set
/// swap a one-file change.
@immutable
class AppIcons {
  const AppIcons._();

  static const IconData accountCircle = LucideIcons.circleUserRound;
  static const IconData add = LucideIcons.plus;
  static const IconData analytics = LucideIcons.chartColumn;
  static const IconData arrowBack = LucideIcons.arrowLeft;
  static const IconData brightness6 = LucideIcons.sunMoon;
  static const IconData check = LucideIcons.check;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData clear = LucideIcons.x;
  static const IconData close = LucideIcons.x;
  static const IconData cloud = LucideIcons.cloud;
  static const IconData code = LucideIcons.code;
  static const IconData colorize = LucideIcons.pipette;
  static const IconData copy = LucideIcons.copy;
  static const IconData createNewFolder = LucideIcons.folderPlus;
  static const IconData delete = LucideIcons.trash2;
  static const IconData deleteSweep = LucideIcons.trash;
  static const IconData description = LucideIcons.fileText;
  static const IconData download = LucideIcons.download;
  static const IconData downloadDone = LucideIcons.circleCheckBig;
  static const IconData downloadDoneOutlined = LucideIcons.circleCheckBig;
  static const IconData edit = LucideIcons.pencil;
  static const IconData editOutlined = LucideIcons.pencil;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData favorite = LucideIcons.heart;
  static const IconData favoriteBorder = LucideIcons.heart;
  static const IconData favoriteActive = LucideIcons600.heart;
  static const IconData folder = LucideIcons.folder;
  static const IconData folderOff = LucideIcons.folderX;
  static const IconData graphicEq = LucideIcons.audioLines;
  static const IconData gridView = LucideIcons.layoutGrid;
  static const IconData home = LucideIcons.house;
  static const IconData image = LucideIcons.image;
  static const IconData imageNotSupported = LucideIcons.imageOff;
  static const IconData info = LucideIcons.info;
  static const IconData keyboardArrowDown = LucideIcons.chevronDown;
  static const IconData language = LucideIcons.languages;
  static const IconData libraryAdd = LucideIcons.listPlus;
  static const IconData libraryMusic = LucideIcons.disc3;
  static const IconData libraryMusicOutlined = LucideIcons.disc3;
  static const IconData lyrics = LucideIcons.textQuote;
  static const IconData moreVert = LucideIcons.ellipsisVertical;
  static const IconData musicNote = LucideIcons.music;
  static const IconData musicOff = LucideIcons.music2;
  static const IconData offlinePin = LucideIcons.hardDriveDownload;
  static const IconData openInFull = LucideIcons.maximize2;
  // Lucide has no Fill weight. The primary transport is the one place where
  // a solid glyph is the right material: a filled rounded triangle / bars
  // inside the filled play button, so the button does not read as hollow.
  static const IconData pause = Icons.pause_rounded;
  static const IconData person = LucideIcons.user;
  static const IconData playArrow = Icons.play_arrow_rounded;
  static const IconData playCircle = LucideIcons.circlePlay;
  static const IconData playlistAdd = LucideIcons.listPlus;
  static const IconData playlistPlay = LucideIcons.listStart;
  static const IconData playlistRemove = LucideIcons.listX;
  static const IconData qrCode = LucideIcons.qrCode;
  static const IconData queueMusic = LucideIcons.listMusic;
  static const IconData radioButtonChecked = LucideIcons.circleDot;
  static const IconData radioButtonUnchecked = LucideIcons.circle;
  static const IconData refresh = LucideIcons.refreshCw;
  static const IconData repeat = LucideIcons.repeat;
  static const IconData repeatOne = LucideIcons.repeat1;
  static const IconData sdStorage = LucideIcons.hardDrive;
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.searchX;
  static const IconData searchOutlined = LucideIcons.search;
  static const IconData settings = LucideIcons.settings;
  static const IconData settingsOutlined = LucideIcons.settings;
  static const IconData shuffle = LucideIcons.shuffle;
  static const IconData skipNext = LucideIcons.skipForward;
  static const IconData skipPrevious = LucideIcons.skipBack;
  static const IconData sort = LucideIcons.arrowUpDown;
  static const IconData speed = LucideIcons.gauge;
  static const IconData timer = LucideIcons.timer;
  static const IconData timerOutlined = LucideIcons.timer;
  static const IconData tune = LucideIcons.slidersHorizontal;
  static const IconData volumeDown = LucideIcons.volume1;
  static const IconData volumeOff = LucideIcons.volumeX;
  static const IconData volumeUp = LucideIcons.volume2;
}
