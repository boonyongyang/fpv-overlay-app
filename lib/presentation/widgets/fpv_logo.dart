import 'package:flutter/material.dart';

class FpvLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const FpvLogo({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FpvDronePainter(color: logoColor),
      ),
    );
  }
}

class _FpvDronePainter extends CustomPainter {
  final Color color;

  _FpvDronePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.08;
    final propellerRadius = size.width * 0.15;
    final center = Offset(size.width / 2, size.height / 2);

    // Paint for stroked elements
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Paint for filled elements
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Draw the "X" frame
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      strokePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      strokePaint,
    );

    // 2. Draw the central body (filled)
    final bodyRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.25,
      height: size.height * 0.45,
    );
    final bodyRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.05));
    canvas.drawRRect(bodyRRect, fillPaint);

    // Draw body outline (stroked)
    canvas.drawRRect(bodyRRect, strokePaint);

    // 3. Draw Propellers at the ends
    final propellerPositions = [
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.8),
    ];

    for (final pos in propellerPositions) {
      // Draw propeller circle
      canvas.drawCircle(pos, propellerRadius, strokePaint);

      // Draw cross in the middle of propeller
      final crossPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(pos.dx - propellerRadius * 0.5, pos.dy),
        Offset(pos.dx + propellerRadius * 0.5, pos.dy),
        crossPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
