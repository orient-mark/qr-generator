import 'package:flutter/material.dart';

class GitHubIcon extends StatelessWidget {
  const GitHubIcon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(22),
    painter: _GitHubIconPainter(
      IconTheme.of(context).color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}

class _GitHubIconPainter extends CustomPainter {
  const _GitHubIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // GitHub Octicons mark-github (MIT): https://github.com/primer/octicons
    final path = Path()
      ..moveTo(8, 0)
      ..cubicTo(3.58, 0, 0, 3.58, 0, 8)
      ..relativeCubicTo(0, 3.54, 2.29, 6.53, 5.47, 7.59)
      ..relativeCubicTo(.4, .07, .55, -.17, .55, -.38)
      ..relativeCubicTo(0, -.19, -.01, -.82, -.01, -1.49)
      ..relativeCubicTo(-2.01, .37, -2.53, -.49, -2.69, -.94)
      ..relativeCubicTo(-.09, -.23, -.48, -.94, -.82, -1.13)
      ..relativeCubicTo(-.28, -.15, -.68, -.52, -.01, -.53)
      ..relativeCubicTo(.63, -.01, 1.08, .58, 1.23, .82)
      ..relativeCubicTo(.72, 1.21, 1.87, .87, 2.33, .66)
      ..relativeCubicTo(.07, -.52, .28, -.87, .51, -1.07)
      ..relativeCubicTo(-1.78, -.2, -3.64, -.89, -3.64, -3.95)
      ..relativeCubicTo(0, -.87, .31, -1.59, .82, -2.15)
      ..relativeCubicTo(-.08, -.2, -.36, -1.02, .08, -2.12)
      ..relativeCubicTo(0, 0, .67, -.21, 2.2, .82)
      ..relativeArcToPoint(
        const Offset(2, -.27),
        radius: const Radius.circular(7.65),
      )
      ..relativeCubicTo(.68, 0, 1.36, .09, 2, .27)
      ..relativeCubicTo(1.53, -1.04, 2.2, -.82, 2.2, -.82)
      ..relativeCubicTo(.44, 1.1, .16, 1.92, .08, 2.12)
      ..relativeCubicTo(.51, .56, .82, 1.27, .82, 2.15)
      ..relativeCubicTo(0, 3.07, -1.87, 3.75, -3.65, 3.95)
      ..relativeCubicTo(.29, .25, .54, .73, .54, 1.48)
      ..relativeCubicTo(0, 1.07, -.01, 1.93, -.01, 2.2)
      ..relativeCubicTo(0, .21, .15, .46, .55, .38)
      ..arcToPoint(
        const Offset(16, 8),
        radius: const Radius.circular(8.013),
        clockwise: false,
      )
      ..cubicTo(16, 3.58, 12.42, 0, 8, 0)
      ..close();
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GitHubIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
