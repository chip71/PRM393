import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Vẽ 2 lớp sóng để tạo độ sâu
    _drawWave(canvas, size, paint, animationValue, size.height * 0.5, 20);
    _drawWave(canvas, size, paint, animationValue + 0.5, size.height * 0.6, 15);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double anim, double baseHeight, double waveHeight) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        baseHeight + math.sin((i / size.width * 2 * math.pi) + (anim * 2 * math.pi)) * waveHeight,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}