import 'package:flutter/widgets.dart';

/// Applies brightness / contrast / saturation via a ColorMatrix.
class FilterLayer extends StatelessWidget {
  const FilterLayer({
    super.key,
    required this.child,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
  });

  final Widget child;

  /// Range: -1.0 (dark) to 1.0 (bright). Default 0.0.
  final double brightness;

  /// Range: 0.5 (low) to 2.0 (high). Default 1.0.
  final double contrast;

  /// Range: 0.0 (greyscale) to 2.0 (vivid). Default 1.0.
  final double saturation;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_buildMatrix()),
      child: child,
    );
  }

  List<double> _buildMatrix() {
    // Contrast matrix (anchor at 0.5)
    final t = (1.0 - contrast) * 0.5;

    // Saturation weights (perceptual luminance)
    const rw = 0.2126;
    const gw = 0.7152;
    const bw = 0.0722;
    final sr = (1.0 - saturation) * rw;
    final sg = (1.0 - saturation) * gw;
    final sb = (1.0 - saturation) * bw;

    final r = sr + saturation;
    final g = sg;
    final b = sb;

    // Combined 5x4 color matrix:
    // [ R  G  B  A  T ]  (rows = output channel)
    return [
      r * contrast, g * contrast, b * contrast, 0, (t + brightness) * 255,
      sr * contrast, (sg + saturation) * contrast, sb * contrast, 0, (t + brightness) * 255,
      sr * contrast, sg * contrast, (sb + saturation) * contrast, 0, (t + brightness) * 255,
      0, 0, 0, 1, 0,
    ];
  }
}
