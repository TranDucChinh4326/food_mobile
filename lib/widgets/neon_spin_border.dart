import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hiệu ứng viền Neon Laser xoay 360 độ vật lý chạy vòng quanh thẻ liên tục
/// Tái tạo chính xác 100% animation `borderNeonBeamSpin` từ bản Web CSS:
/// - 2 chùm tia laser rực rỡ (Cyan -> Purple -> Pink -> White chói và Lime -> Yellow -> Red -> White chói)
/// - Hiệu ứng tỏa sáng Neon Drop Shadow
/// - Dùng CustomPainter shader GPU hardware acceleration siêu mượt 60/120fps, không làm lag widget con
class NeonSpinBorder extends StatefulWidget {
  const NeonSpinBorder({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.borderWidth = 2.5,
    this.glow = true,
    this.duration = const Duration(milliseconds: 2200),
    this.enabled = true,
  });

  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final bool glow;
  final Duration duration;
  final bool enabled;

  @override
  State<NeonSpinBorder> createState() => _NeonSpinBorderState();
}

class _NeonSpinBorderState extends State<NeonSpinBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant NeonSpinBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _NeonBorderPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
            glow: widget.glow,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _NeonBorderPainter extends CustomPainter {
  _NeonBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.glow,
  });

  final double progress;
  final double borderRadius;
  final double borderWidth;
  final bool glow;

  // Gradient 2 đốm sáng Neon Laser chuẩn Web base.css & food-detail.css
  static const List<Color> _neonColors = [
    // Đốm sáng Neon 1: Electric Cyan -> Neon Purple -> Hot Pink -> Trắng sáng chói
    Colors.transparent,
    Colors.transparent,
    Color(0x4D00F0FF), // rgba(0, 240, 255, 0.3)
    Color(0xFF00F0FF), // #00f0ff
    Color(0xFF9D00FF), // #9d00ff
    Color(0xFFFF007F), // #ff007f
    Color(0xFFFFFFFF), // #ffffff (Trắng chói)
    // Đốm sáng Neon 2: Neon Green -> Electric Yellow -> Blazing Red-Orange -> Trắng sáng chói
    Colors.transparent,
    Colors.transparent,
    Color(0x4D00FF88), // rgba(0, 255, 128, 0.3)
    Color(0xFF00FF88), // #00ff88
    Color(0xFFFFEA00), // #ffea00
    Color(0xFFFF0055), // #ff0055
    Color(0xFFFFFFFF), // #ffffff (Trắng chói)
  ];

  static const List<double> _neonStops = [
    0.0,
    35 / 360,
    70 / 360,
    110 / 360,
    145 / 360,
    168 / 360,
    180 / 360,
    180.1 / 360,
    215 / 360,
    250 / 360,
    290 / 360,
    325 / 360,
    348 / 360,
    1.0,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final halfWidth = borderWidth / 2;
    final outerRect = Rect.fromLTWH(
      halfWidth,
      halfWidth,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      outerRect,
      Radius.circular(math.max(0, borderRadius - halfWidth)),
    );

    final angle = progress * 2 * math.pi;

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      colors: _neonColors,
      stops: _neonStops,
      transform: GradientRotation(angle),
    );

    final shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final shader = sweepGradient.createShader(shaderRect);

    // 1. Vẽ quầng hào quang phát sáng (Neon Glow)
    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 3.0
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawRRect(rrect, glowPaint);
    }

    // 2. Vẽ tia sáng sắc nét chính chạy viền
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _NeonBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.glow != glow;
}
