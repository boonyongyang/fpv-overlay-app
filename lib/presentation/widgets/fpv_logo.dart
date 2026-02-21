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
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.15; // Propeller radius

    // 1. Draw the "X" frame
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      paint,
    );

    // 2. Draw the central body
    final bodyRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.25,
      height: size.height * 0.45,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.05)),
      paint..style = PaintingStyle.fill,
    );

    // Draw body outline
    paint.style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(size.width * 0.05)),
      paint,
    );

    // 3. Draw Propellers at the ends
    final positions = [
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.8),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, r, paint);
      // Small cross in the middle of propeller
      canvas.drawLine(
        Offset(pos.dx - r * 0.5, pos.dy),
        Offset(pos.dx + r * 0.5, pos.dy),
        paint..strokeWidth = size.width * 0.04,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
