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

import 'package:flind_player/data/sources/bilibili/bili_client.dart';

/// Maps an arbitrary [error] to a short, user-facing Chinese message.
///
/// Pure and Flutter-free so it can be unit-tested and reused from any layer.
/// Bilibili codes follow `docs/bilibili-source.md` §6:
///
/// * `-412` / `-509` / `-799` are rate limits,
/// * `-352` is the risk-control block,
/// * `-101` means the request needs a logged-in account.
///
/// Never returns a raw stack trace: anything unrecognised falls back to a
/// generic message.
String describeError(Object error) {
  if (error is BiliApiException) {
    return switch (error.code) {
      -412 || -509 || -799 => '请求过于频繁，请稍后再试',
      -352 => '触发风控，请稍后再试',
      -101 => '需要登录',
      _ => 'Bilibili 接口错误（code: ${error.code}）',
    };
  }
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException) {
    return '网络连接失败，请检查网络';
  }
  if (error is FormatException) {
    return '数据格式异常';
  }
  // StateError / UnsupportedError messages are written for developers but are
  // still the most useful text available for these programming-level faults.
  if (error is UnsupportedError) {
    final message = error.message;
    return (message == null || message.isEmpty) ? '操作失败，请重试' : message;
  }
  if (error is StateError) {
    return error.message.isEmpty ? '操作失败，请重试' : error.message;
  }
  return '操作失败，请重试';
}
