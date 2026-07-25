import 'package:flutter/material.dart';
import 'package:qistiraha/core/theme/app_theme.dart';

/// A tiny, axis-less trend line for KPI cards — gives a number immediate
/// context without the weight of a full chart. Draws a smoothed line with a
/// soft gradient fill and a dot on the latest point. Purely presentational.
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double strokeWidth;

  const Sparkline({
    super.key,
    required this.data,
    this.color = AppColors.accent,
    this.height = 32,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce((a, b) => a < b ? a : b);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (data.length - 1);

    double yFor(double v) {
      // 10% vertical padding so the line never clips the card edge.
      final t = (v - minV) / range;
      return size.height - (t * (size.height * 0.8)) - (size.height * 0.1);
    }

    final points = <Offset>[
      for (int i = 0; i < data.length; i++) Offset(i * dx, yFor(data[i])),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      // Gentle Catmull-Rom-ish smoothing via midpoint quadratics.
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      line.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      line.lineTo(curr.dx, curr.dy);
    }

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(points.last, strokeWidth + 1.2, Paint()..color = color);
    canvas.drawCircle(
      points.last,
      strokeWidth + 0.2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.color != color;
}
