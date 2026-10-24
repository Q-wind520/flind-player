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

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The now-playing progress track.
///
/// It morphs between a straight rail (paused) and a shallow wave (playing),
/// and switches to a travelling-dot animation while the current track is
/// buffering. The active portion and the draggable thumb keep the theme's
/// primary colour; the remaining rail stays quiet.
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.value,
    required this.isPlaying,
    this.isBuffering = false,
    this.enabled = true,
    this.height = 36,
    this.morphDuration = const Duration(milliseconds: 400),
    this.onChanged,
    this.onChangeEnd,
  });

  /// Playback position in the `0...1` range.
  final double value;

  /// Whether the track is currently playing.
  final bool isPlaying;

  /// Whether the player is waiting for audio data.
  final bool isBuffering;

  /// Whether seeking is available. A disabled bar paints no thumb.
  final bool enabled;

  /// Height of the hit area and painter.
  final double height;

  /// Duration of the wave ⇄ straight morph.
  ///
  /// The player passes the playback fade duration so the wave settles exactly
  /// as the audio fade-in/out completes.
  final Duration morphDuration;

  /// Called continuously while the finger drags the thumb.
  final ValueChanged<double>? onChanged;

  /// Called once the drag/tap ends with the final `0...1` position.
  final ValueChanged<double>? onChangeEnd;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: widget.morphDuration,
    value: widget.isPlaying ? 1 : 0,
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  /// Scrolls the sine phase so the playing wave travels sideways instead of
  /// standing still like a mountain range.
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _dragging = false;
  double? _dragValue;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _syncAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      if (reduceMotion) {
        _wave.value = widget.isPlaying ? 1 : 0;
      }
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    _syncFlow();
    if (widget.isBuffering && !_reduceMotion) {
      if (!_dots.isAnimating) {
        _dots.repeat();
      }
    } else {
      _dots
        ..stop()
        ..value = 0;
    }
  }

  void _syncFlow() {
    if (!_reduceMotion && widget.isPlaying && !widget.isBuffering) {
      if (!_flow.isAnimating) {
        _flow.repeat();
      }
    } else {
      _flow.stop();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _wave.duration = widget.morphDuration;
      if (_reduceMotion) {
        _wave.value = widget.isPlaying ? 1 : 0;
      } else {
        _wave.animateTo(
          widget.isPlaying ? 1 : 0,
          duration: widget.morphDuration,
          curve: Curves.easeInOutCubic,
        );
      }
    }
    _syncAnimations();
  }

  @override
  void dispose() {
    _wave.dispose();
    _dots.dispose();
    _flow.dispose();
    super.dispose();
  }

  double _valueFor(double dx, double width) {
    const inset = _WaveProgressPainter.thumbRadius;
    final usable = width - inset * 2;
    if (usable <= 0) return 0;
    return ((dx - inset) / usable).clamp(0.0, 1.0);
  }

  void _start(double dx, double width) {
    if (!widget.enabled) return;
    final value = _valueFor(dx, width);
    setState(() {
      _dragging = true;
      _dragValue = value;
    });
    widget.onChanged?.call(value);
  }

  void _update(double dx, double width) {
    if (!widget.enabled) return;
    final value = _valueFor(dx, width);
    setState(() {
      _dragging = true;
      _dragValue = value;
    });
    widget.onChanged?.call(value);
  }

  void _end() {
    if (!_dragging) return;
    final value = _dragValue;
    setState(() => _dragging = false);
    if (value != null) {
      widget.onChangeEnd?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final displayValue =
        (_dragging ? _dragValue : widget.value)?.clamp(0.0, 1.0) ??
        widget.value.clamp(0.0, 1.0);

    return Semantics(
      slider: true,
      enabled: widget.enabled,
      value: '${(displayValue * 100).round()}%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.enabled
                ? (details) {
                    final value = _valueFor(details.localPosition.dx, width);
                    widget.onChanged?.call(value);
                    widget.onChangeEnd?.call(value);
                  }
                : null,
            onHorizontalDragStart: widget.enabled
                ? (details) => _start(details.localPosition.dx, width)
                : null,
            onHorizontalDragUpdate: widget.enabled
                ? (details) => _update(details.localPosition.dx, width)
                : null,
            onHorizontalDragEnd: widget.enabled ? (_) => _end() : null,
            onHorizontalDragCancel: widget.enabled
                ? () => setState(() => _dragging = false)
                : null,
            child: SizedBox(
              width: double.infinity,
              height: widget.height,
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_wave, _dots, _flow]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WaveProgressPainter(
                      value: displayValue,
                      wave: disableAnimations ? 0 : _wave.value,
                      flowPhase: disableAnimations ? 0 : _flow.value,
                      dotsPhase: disableAnimations ? 0 : _dots.value,
                      isBuffering: widget.isBuffering,
                      enabled: widget.enabled,
                      activeColor: scheme.primary,
                      trackColor: scheme.onSurface.withValues(alpha: 0.22),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveProgressPainter extends CustomPainter {
  _WaveProgressPainter({
    required this.value,
    required this.wave,
    required this.flowPhase,
    required this.dotsPhase,
    required this.isBuffering,
    required this.enabled,
    required this.activeColor,
    required this.trackColor,
  });

  static const double thumbRadius = 6;
  static const double _trackWidth = 3;
  static const double _wavelength = 48;

  final double value;
  final double wave;
  final double flowPhase;
  final double dotsPhase;
  final bool isBuffering;
  final bool enabled;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final left = thumbRadius;
    final right = size.width - thumbRadius;
    final width = right - left;
    if (width <= 0) return;

    final centerY = size.height / 2;
    if (isBuffering) {
      _paintDots(canvas, left, width, centerY);
      return;
    }

    final amplitude = 4.5 * wave * (0.9 + 0.1 * math.sin(flowPhase * math.pi));
    final path = _wavePath(left, width, centerY, amplitude);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _trackWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, trackPaint);

    final progress = value.clamp(0.0, 1.0);
    final thumbX = left + width * progress;
    // Ride the wave instead of sitting on the centre line: the dot bobs up and
    // down with the same sine that paints the track.
    final thumbY =
        centerY +
        math.sin(
              (thumbX - left) / _wavelength * math.pi * 2 +
                  flowPhase * math.pi * 2,
            ) *
            amplitude;
    if (progress > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, thumbX, size.height));
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _trackWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, activePaint);
      canvas.restore();
    }

    if (enabled) {
      canvas.drawCircle(
        Offset(thumbX, thumbY),
        thumbRadius + 4,
        Paint()..color = activeColor.withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        Offset(thumbX, thumbY),
        thumbRadius,
        Paint()..color = activeColor,
      );
    }
  }

  void _paintDots(Canvas canvas, double left, double width, double centerY) {
    final count = math.max(10, (width / 18).round());
    final step = width / count;
    for (var index = 0; index < count; index++) {
      final phase = dotsPhase * math.pi * 2 - index * 0.65;
      final pulse = (math.sin(phase) + 1) / 2;
      final x = left + (index + 0.5) * step;
      canvas.drawCircle(
        Offset(x, centerY),
        1.4 + 2.2 * pulse,
        Paint()..color = activeColor.withValues(alpha: 0.25 + 0.75 * pulse),
      );
    }
  }

  Path _wavePath(double left, double width, double centerY, double amplitude) {
    final phase = flowPhase * math.pi * 2;
    final path = Path()..moveTo(left, centerY + math.sin(phase) * amplitude);
    for (double dx = 1.5; dx <= width; dx += 1.5) {
      final y =
          centerY +
          math.sin(dx / _wavelength * math.pi * 2 + phase) * amplitude;
      path.lineTo(left + dx, y);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _WaveProgressPainter oldDelegate) {
    return value != oldDelegate.value ||
        wave != oldDelegate.wave ||
        flowPhase != oldDelegate.flowPhase ||
        dotsPhase != oldDelegate.dotsPhase ||
        isBuffering != oldDelegate.isBuffering ||
        enabled != oldDelegate.enabled ||
        activeColor != oldDelegate.activeColor ||
        trackColor != oldDelegate.trackColor;
  }
}
