import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// House-shaped CampusStay mark, drawn in code so it is crisp at any size.
class LogoMark extends StatelessWidget {
  final double size;
  final bool onDark;
  const LogoMark({super.key, this.size = 56, this.onDark = false});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _LogoPainter(onDark),
      );
}

class _LogoPainter extends CustomPainter {
  final bool onDark;
  _LogoPainter(this.onDark);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final roof = Paint()
      ..color = CS.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final roofPath = Path()
      ..moveTo(w * 0.08, h * 0.46)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.92, h * 0.46);
    canvas.drawPath(roofPath, roof);

    final body = Paint()..color = onDark ? Colors.white : CS.navy;
    final bodyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.42, w * 0.6, h * 0.5), Radius.circular(w * 0.06));
    canvas.drawRRect(bodyRect, body);

    final door = Paint()..color = CS.blue;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.42, h * 0.62, w * 0.16, h * 0.3), Radius.circular(w * 0.03)),
        door);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.onDark != onDark;
}

class LogoLockup extends StatelessWidget {
  final bool onDark;
  final bool showTagline;
  final double size;
  const LogoLockup({super.key, this.onDark = false, this.showTagline = true, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final color = onDark ? Colors.white : CS.navy;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      LogoMark(size: size, onDark: onDark),
      const SizedBox(height: 8),
      Text('CampusStay',
          style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
      if (showTagline)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Find Your Space. Live Your Dreams.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: onDark ? Colors.white70 : CS.muted)),
        ),
    ]);
  }
}
