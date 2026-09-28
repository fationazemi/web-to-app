import 'package:flutter/material.dart';

/// Shows a simple HSV color picker and returns the chosen color, or `null`
/// when dismissed.
Future<Color?> showColorPickerDialog(BuildContext context, {required Color initial}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  String get _hex =>
      '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            alignment: Alignment.center,
            child: Text(
              _hex,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _hsv.value > 0.6 && _hsv.saturation < 0.6 ? Colors.black : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GradientSlider(
            label: 'Hue',
            value: _hsv.hue / 360,
            colors: [for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor()],
            onChanged: (v) => setState(() => _hsv = _hsv.withHue(v * 360)),
          ),
          _GradientSlider(
            label: 'Saturation',
            value: _hsv.saturation,
            colors: [_hsv.withSaturation(0).toColor(), _hsv.withSaturation(1).toColor()],
            onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
          ),
          _GradientSlider(
            label: 'Brightness',
            value: _hsv.value,
            colors: [_hsv.withValue(0).toColor(), _hsv.withValue(1).toColor()],
            onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _color), child: const Text('Use color')),
      ],
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 2),
                ),
                child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
