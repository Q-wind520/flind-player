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

import 'package:flind_player/core/models/app_theme_color.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Shows the theme-colour picker and resolves to the chosen colour, or `null`
/// when the user dismisses it.
///
/// The persisted value is the caller's concern; this dialog only gathers the
/// choice. It offers the four recommended swatches plus a custom channel that
/// is edited either as hex or with R/G/B sliders.
Future<AppThemeColor?> showThemeColorPicker(
  BuildContext context, {
  required AppThemeColor initial,
}) {
  return showDialog<AppThemeColor>(
    context: context,
    builder: (context) => _ThemeColorDialog(initial: initial),
  );
}

class _ThemeColorDialog extends StatefulWidget {
  const _ThemeColorDialog({required this.initial});

  final AppThemeColor initial;

  @override
  State<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<_ThemeColorDialog> {
  late final TextEditingController _hex;
  late int _red;
  late int _green;
  late int _blue;

  /// Whether the custom channel is expanded. Starts open when the saved colour
  /// is not one of the recommended swatches.
  late bool _custom;

  @override
  void initState() {
    super.initState();
    _red = (widget.initial.argb >> 16) & 0xFF;
    _green = (widget.initial.argb >> 8) & 0xFF;
    _blue = widget.initial.argb & 0xFF;
    _custom = !AppThemeColor.recommended.contains(widget.initial);
    _hex = TextEditingController(text: _color.toHex());
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  AppThemeColor get _color =>
      AppThemeColor(0xFF000000 | (_red << 16) | (_green << 8) | _blue);

  void _selectRecommended(AppThemeColor color) {
    setState(() {
      _red = (color.argb >> 16) & 0xFF;
      _green = (color.argb >> 8) & 0xFF;
      _blue = color.argb & 0xFF;
      _custom = false;
      _hex.text = _color.toHex();
    });
  }

  void _selectCustom() {
    setState(() => _custom = true);
  }

  void _onHexChanged(String value) {
    final parsed = AppThemeColor.tryParseHex(value);
    setState(() {
      if (parsed != null) {
        _red = (parsed.argb >> 16) & 0xFF;
        _green = (parsed.argb >> 8) & 0xFF;
        _blue = parsed.argb & 0xFF;
      }
    });
  }

  void _onChannelChanged() {
    setState(() => _hex.text = _color.toHex());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invalidHex =
        _hex.text.isNotEmpty && AppThemeColor.tryParseHex(_hex.text) == null
        ? l10n.themeColorInvalidHex
        : null;

    return AlertDialog(
      title: Text(l10n.themeColor),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final color in AppThemeColor.recommended)
                    _Swatch(
                      key: Key('theme-color-swatch-${color.toHex()}'),
                      color: color.toColor(),
                      selected: !_custom && _color == color,
                      onTap: () => _selectRecommended(color),
                    ),
                  _CustomSwatch(
                    color: _color.toColor(),
                    selected: _custom,
                    onTap: _selectCustom,
                  ),
                ],
              ),
              if (_custom) ...[
                const SizedBox(height: 20),
                TextField(
                  key: const Key('theme-color-hex'),
                  controller: _hex,
                  onChanged: _onHexChanged,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.themeColorHex,
                    hintText: '#1BA784',
                    errorText: invalidHex,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                _ChannelSlider(
                  sliderKey: const Key('theme-color-slider-r'),
                  label: 'R',
                  value: _red,
                  onChanged: (value) {
                    _red = value;
                    _onChannelChanged();
                  },
                ),
                _ChannelSlider(
                  sliderKey: const Key('theme-color-slider-g'),
                  label: 'G',
                  value: _green,
                  onChanged: (value) {
                    _green = value;
                    _onChannelChanged();
                  },
                ),
                _ChannelSlider(
                  sliderKey: const Key('theme-color-slider-b'),
                  label: 'B',
                  value: _blue,
                  onChanged: (value) {
                    _blue = value;
                    _onChannelChanged();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

/// A circular recommended-colour swatch with a check when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    );
  }
}

/// The custom channel entry point: the current custom colour with a pencil.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const Key('theme-color-custom'),
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: Icon(
          Icons.colorize,
          size: 20,
          color: selected
              ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                    ? Colors.white
                    : Colors.black)
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A labelled 0–255 slider for one colour channel.
class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: Slider(
            key: sliderKey,
            min: 0,
            max: 255,
            value: value.toDouble(),
            label: '$value',
            onChanged: (raw) => onChanged(raw.round()),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}
