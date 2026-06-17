import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zenverse/app/theme/app_colors.dart';

class SpaceScaffold extends StatelessWidget {
  const SpaceScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            const Color(0xFF0D2333),
            const Color(0xFF12142A),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              const Color(0xFF401A6A).withValues(alpha: 0.22),
              Colors.transparent,
              AppColors.primary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          bottomNavigationBar: bottomNavigationBar,
          body: SafeArea(child: Padding(padding: padding, child: body)),
        ),
      ),
    );
  }
}

class ZenLogo extends StatelessWidget {
  const ZenLogo({super.key, this.size = 96, this.glow = true});
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: size * 0.5,
                    spreadRadius: size * 0.1,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(
            'assets/branding/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

enum PlanetType { earth, mars, saturn, neptune, venus, moon, jupiter, uranus }

class PlanetWidget extends StatefulWidget {
  const PlanetWidget({
    super.key,
    required this.type,
    this.size = 220,
    this.glow = true,
  });

  final PlanetType type;
  final double size;
  final bool glow;

  @override
  State<PlanetWidget> createState() => _PlanetWidgetState();
}

class _PlanetWidgetState extends State<PlanetWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _PlanetPainter(
            type: widget.type,
            t: _controller.value,
            glow: widget.glow,
          ),
        ),
      ),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter({required this.type, required this.t, required this.glow});

  final PlanetType type;
  final double t;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);

    // Atmosphere glow
    if (glow) {
      final glowPaint = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25)
        ..color = _accent.withValues(alpha: 0.22);
      canvas.drawCircle(c, r * 1.05, glowPaint);
    }

    // Sphere base (radial gradient + light source)
    final sphereRect = Rect.fromCircle(center: c, radius: r * 0.92);
    final light = Offset(-0.45, -0.55); // light from top-left (normalized-ish)
    final lightCenter = c + Offset(light.dx * r, light.dy * r);
    final baseGradient = RadialGradient(
      center: Alignment((light.dx * 0.9), (light.dy * 0.9)),
      radius: 1.25,
      colors: [
        _baseBright,
        _baseMid,
        _baseDark,
        const Color(0xFF04060C),
      ],
      stops: const [0.0, 0.42, 0.78, 1.0],
    );
    final spherePaint = Paint()..shader = baseGradient.createShader(sphereRect);
    canvas.drawCircle(c, r * 0.92, spherePaint);

    // Texture layer (subtle bands / noise) clipped to sphere.
    canvas.save();
    canvas.clipPath(Path()..addOval(sphereRect));
    _paintTexture(canvas, sphereRect, r, lightCenter);
    canvas.restore();

    // Terminator shadow (night side)
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment((light.dx * -0.8), (light.dy * -0.8)),
        radius: 1.4,
        colors: [
          Colors.transparent,
          const Color(0xFF02030A).withValues(alpha: 0.35),
          const Color(0xFF000000).withValues(alpha: 0.75),
        ],
        stops: const [0.35, 0.70, 1.0],
      ).createShader(sphereRect);
    canvas.drawCircle(c, r * 0.92, shadowPaint);

    // Rim highlight
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.02
      ..color = _accent.withValues(alpha: 0.22);
    canvas.drawCircle(c, r * 0.92, rim);

    // Saturn rings (draw above + below for depth)
    if (type == PlanetType.saturn) {
      _paintSaturnRings(canvas, c, r);
    }
  }

  void _paintTexture(Canvas canvas, Rect sphereRect, double r, Offset lightCenter) {
    // Moving longitude offset (rotation illusion).
    final shift = (t * 2 * 3.14159);
    final p = Paint()..blendMode = BlendMode.softLight;

    switch (type) {
      case PlanetType.earth:
        // ocean tint
        p.color = const Color(0xFF2E9BFF).withValues(alpha: 0.08);
        canvas.drawRect(sphereRect, p);
        // continents
        _blotches(
          canvas,
          sphereRect,
          seed: 14,
          count: 26,
          color: const Color(0xFF53F2B2).withValues(alpha: 0.22),
          dxPhase: shift,
        );
        // clouds
        _blotches(
          canvas,
          sphereRect,
          seed: 55,
          count: 18,
          color: Colors.white.withValues(alpha: 0.12),
          dxPhase: shift * 1.3,
        );
      case PlanetType.mars:
        // dusty bands
        _bands(
          canvas,
          sphereRect,
          colorA: const Color(0xFFFFA45C).withValues(alpha: 0.18),
          colorB: const Color(0xFF7A2D1E).withValues(alpha: 0.14),
          phase: shift,
        );
        _blotches(
          canvas,
          sphereRect,
          seed: 9,
          count: 14,
          color: const Color(0xFF3A1A13).withValues(alpha: 0.18),
          dxPhase: shift * 0.7,
        );
      case PlanetType.neptune:
        _bands(
          canvas,
          sphereRect,
          colorA: const Color(0xFF3F7DFF).withValues(alpha: 0.22),
          colorB: const Color(0xFF0B214F).withValues(alpha: 0.18),
          phase: shift * 1.1,
        );
      case PlanetType.venus:
        _bands(
          canvas,
          sphereRect,
          colorA: const Color(0xFFFFE0A6).withValues(alpha: 0.22),
          colorB: const Color(0xFFB67B33).withValues(alpha: 0.18),
          phase: shift * 0.45,
        );
      case PlanetType.moon:
        _blotches(
          canvas,
          sphereRect,
          seed: 3,
          count: 20,
          color: Colors.black.withValues(alpha: 0.10),
          dxPhase: shift * 0.25,
        );
      case PlanetType.saturn:
        _bands(
          canvas,
          sphereRect,
          colorA: const Color(0xFFFFE5A8).withValues(alpha: 0.20),
          colorB: const Color(0xFFB17834).withValues(alpha: 0.18),
          phase: shift * 0.6,
        );
      case PlanetType.jupiter:
        _bands(
          canvas,
          sphereRect,
          colorA: const Color(0xFFFFB074).withValues(alpha: 0.22),
          colorB: const Color(0xFF8B4513).withValues(alpha: 0.20),
          phase: shift * 0.8,
        );
        _blotches(
          canvas,
          sphereRect,
          seed: 21,
          count: 10,
          color: const Color(0xFF5C3317).withValues(alpha: 0.16),
          dxPhase: shift * 0.5,
        );
      case PlanetType.uranus:
        _bands(
          canvas,
          sphereRect,
          colorA: const Color(0xFF7FE7E7).withValues(alpha: 0.22),
          colorB: const Color(0xFF1A5C5C).withValues(alpha: 0.18),
          phase: shift * 0.55,
        );
    }

    // Specular-ish highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: lightCenter, radius: r));
    canvas.drawCircle(lightCenter, r * 0.85, highlightPaint);
  }

  void _bands(Canvas canvas, Rect rect, {required Color colorA, required Color colorB, required double phase}) {
    final bandPaint = Paint()..blendMode = BlendMode.softLight;
    final stripes = 8;
    for (var i = 0; i < stripes; i++) {
      final t0 = i / stripes;
      final t1 = (i + 1) / stripes;
      final y0 = rect.top + rect.height * t0;
      final y1 = rect.top + rect.height * t1;
      final wobble = (0.5 + 0.5 * (sin(phase + i * 0.9))) * rect.width * 0.06;
      final rrect = RRect.fromLTRBR(
        rect.left - wobble,
        y0,
        rect.right + wobble,
        y1,
        Radius.circular(rect.width * 0.18),
      );
      bandPaint.color = (i.isEven ? colorA : colorB);
      canvas.drawRRect(rrect, bandPaint);
    }
  }

  void _blotches(
    Canvas canvas,
    Rect rect, {
    required int seed,
    required int count,
    required Color color,
    required double dxPhase,
  }) {
    final rnd = _Seeded(seed);
    final paint = Paint()
      ..color = color
      ..blendMode = BlendMode.softLight;
    for (var i = 0; i < count; i++) {
      final rx = rnd.next();
      final ry = rnd.next();
      final r0 = (0.04 + rnd.next() * 0.10) * rect.width;
      final x = rect.left + rect.width * rx + sin(dxPhase + i) * rect.width * 0.06;
      final y = rect.top + rect.height * ry;
      canvas.drawCircle(Offset(x, y), r0, paint);
    }
  }

  void _paintSaturnRings(Canvas canvas, Offset c, double r) {
    final ringTilt = 0.62;
    final ringRadius = r * 1.05;
    final ringWidth = r * 0.20;
    final ringPhase = (t * 2 * 3.14159);

    void drawRing({required bool behind}) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFF1CC).withValues(alpha: 0.65),
            const Color(0xFFE6B86C).withValues(alpha: 0.55),
            const Color(0xFF8B5A1F).withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: ringRadius));

      final ringRect = Rect.fromCenter(
        center: c,
        width: ringRadius * 2.2,
        height: ringRadius * 2.2 * ringTilt,
      );

      // Draw half-ellipse for depth: behind goes back half, front goes front half
      final start = behind ? pi : 0.0;
      final sweep = pi;

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(0.18 * sin(ringPhase));
      canvas.translate(-c.dx, -c.dy);
      canvas.drawArc(ringRect, start, sweep, false, ringPaint);

      // subtle ring highlight
      final hi = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth * 0.35
        ..color = Colors.white.withValues(alpha: behind ? 0.06 : 0.10);
      canvas.drawArc(ringRect.deflate(ringWidth * 0.22), start, sweep, false, hi);
      canvas.restore();
    }

    // back half
    drawRing(behind: true);
    // front half
    drawRing(behind: false);
  }

  Color get _accent => switch (type) {
        PlanetType.earth => const Color(0xFF18E4D4),
        PlanetType.mars => const Color(0xFFFF8B3D),
        PlanetType.saturn => const Color(0xFFFFD08A),
        PlanetType.neptune => const Color(0xFF4F8CFF),
        PlanetType.venus => const Color(0xFFFFE0A6),
        PlanetType.moon => const Color(0xFFBFC7D6),
        PlanetType.jupiter => const Color(0xFFFF8C42),
        PlanetType.uranus => const Color(0xFF4DD0C8),
      };

  Color get _baseBright => switch (type) {
        PlanetType.earth => const Color(0xFF4FE7FF),
        PlanetType.mars => const Color(0xFFFFB26A),
        PlanetType.saturn => const Color(0xFFFFE7B3),
        PlanetType.neptune => const Color(0xFF4C6DFF),
        PlanetType.venus => const Color(0xFFFFE6B8),
        PlanetType.moon => const Color(0xFFDEE2EA),
        PlanetType.jupiter => const Color(0xFFFFB26A),
        PlanetType.uranus => const Color(0xFF8AE8E0),
      };

  Color get _baseMid => switch (type) {
        PlanetType.earth => const Color(0xFF0D3B7A),
        PlanetType.mars => const Color(0xFFC15A2B),
        PlanetType.saturn => const Color(0xFFD0A15C),
        PlanetType.neptune => const Color(0xFF133A8A),
        PlanetType.venus => const Color(0xFFB98033),
        PlanetType.moon => const Color(0xFF7D8698),
        PlanetType.jupiter => const Color(0xFF9A4E1F),
        PlanetType.uranus => const Color(0xFF2A7A75),
      };

  Color get _baseDark => switch (type) {
        PlanetType.earth => const Color(0xFF041329),
        PlanetType.mars => const Color(0xFF2B0E0A),
        PlanetType.saturn => const Color(0xFF2A1A0A),
        PlanetType.neptune => const Color(0xFF050B1B),
        PlanetType.venus => const Color(0xFF2A1A0A),
        PlanetType.moon => const Color(0xFF0A0C12),
        PlanetType.jupiter => const Color(0xFF1A0E08),
        PlanetType.uranus => const Color(0xFF061818),
      };

  @override
  bool shouldRepaint(covariant _PlanetPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.t != t || oldDelegate.glow != glow;
  }
}

class _Seeded {
  _Seeded(this._seed);
  int _seed;
  double next() {
    // simple LCG
    _seed = (1664525 * _seed + 1013904223) & 0x7fffffff;
    return (_seed % 10000) / 10000.0;
  }
}

class PlanetHero extends StatefulWidget {
  const PlanetHero({super.key, this.size = 220});
  final double size;

  @override
  State<PlanetHero> createState() => _PlanetHeroState();
}

class _PlanetHeroState extends State<PlanetHero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [Color(0xFF89D7B1), Color(0xFF1A2937), Colors.black]),
          boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.34), blurRadius: 30)],
        ),
      ),
    );
  }
}

BoxDecoration zenCard() => BoxDecoration(
      color: AppColors.surfaceSoft.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF243856)),
    );

Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 240,
    this.stroke = 14,
    this.color = AppColors.primary,
    this.trackColor = const Color(0xFF243856),
    required this.child,
  });

  final double progress; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Color trackColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1),
          stroke: stroke,
          color: color,
          trackColor: trackColor,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double stroke;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide / 2) - stroke / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor.withValues(alpha: 0.55);
    canvas.drawCircle(c, r, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: (2 * pi) - (pi / 2),
        colors: [
          color.withValues(alpha: 0.4),
          color,
          AppColors.secondary,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.stroke != stroke ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

Widget primaryButton(String label, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.secondary,
          foregroundColor: const Color(0xFF071C2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );

Widget dangerButton(String label, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
        child: Text(label),
      ),
    );

Widget formInput(
  String hint, {
  bool obscure = false,
  bool readOnly = false,
  TextEditingController? controller,
  TextInputType? keyboardType,
}) =>
    TextField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(hintText: hint),
    );

String formatMMSS(Duration d) {
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$mm:$ss';
}
