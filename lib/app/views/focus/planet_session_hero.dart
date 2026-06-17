import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenverse/app/models/planet_catalog.dart';
import 'package:zenverse/app/views/shared/space_widgets.dart';

/// Centered planet with orbit rings and optional bitmap or painted fallback.
class PlanetSessionHero extends StatefulWidget {
  const PlanetSessionHero({
    super.key,
    required this.planetImagePath,
    required this.planetType,
    this.stackSize = 320,
    this.planetDiameter = 240,
  });

  final String planetImagePath;
  final PlanetType planetType;
  final double stackSize;
  final double planetDiameter;

  @override
  State<PlanetSessionHero> createState() => _PlanetSessionHeroState();
}

class _PlanetSessionHeroState extends State<PlanetSessionHero> with SingleTickerProviderStateMixin {
  bool _useBitmap = false;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
    _resolveAsset();
  }

  @override
  void didUpdateWidget(covariant PlanetSessionHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planetImagePath != widget.planetImagePath) {
      _resolveAsset();
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _resolveAsset() async {
    var useBitmap = false;
    try {
      await rootBundle.load(widget.planetImagePath);
      useBitmap = true;
    } catch (_) {
      useBitmap = false;
    }
    if (!mounted) return;
    setState(() => _useBitmap = useBitmap);
  }

  Color get _planetGlow => PlanetCatalog.byId(_planetIdForType(widget.planetType)).glowColor;

  static String _planetIdForType(PlanetType type) => switch (type) {
        PlanetType.earth => 'earth',
        PlanetType.mars => 'mars',
        PlanetType.moon => 'moon',
        PlanetType.venus => 'venus',
        PlanetType.saturn => 'saturn',
        PlanetType.jupiter => 'jupiter',
        PlanetType.neptune => 'neptune',
        PlanetType.uranus => 'uranus',
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.stackSize,
      height: widget.stackSize,
      child: AnimatedBuilder(
        animation: _orbitController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.stackSize, widget.stackSize),
                painter: OrbitRingsPainter(rotation: _orbitController.value * math.pi * 2),
              ),
              _PlanetDisc(
                diameter: widget.planetDiameter,
                glowColor: _planetGlow,
                useBitmap: _useBitmap,
                imagePath: widget.planetImagePath,
                planetType: widget.planetType,
              ),
              _OrbitingDot(
                angle: _orbitController.value * math.pi * 2,
                ringRadius: 155,
                color: Colors.cyanAccent,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanetDisc extends StatelessWidget {
  const _PlanetDisc({
    required this.diameter,
    required this.glowColor,
    required this.useBitmap,
    required this.imagePath,
    required this.planetType,
  });

  final double diameter;
  final Color glowColor;
  final bool useBitmap;
  final String imagePath;
  final PlanetType planetType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child: useBitmap
            ? Image.asset(imagePath, fit: BoxFit.cover, width: diameter, height: diameter)
            : PlanetWidget(type: planetType, size: diameter, glow: false),
      ),
    );
  }
}

/// Small glowing dot orbiting on the middle ring ellipse.
class _OrbitingDot extends StatelessWidget {
  const _OrbitingDot({
    required this.angle,
    required this.ringRadius,
    required this.color,
  });

  final double angle;
  final double ringRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const verticalSquish = 1.3;
    final rx = ringRadius;
    final ry = ringRadius * verticalSquish / 2;
    final x = rx * math.cos(angle);
    final y = ry * math.sin(angle);

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.85), blurRadius: 10, spreadRadius: 2),
          ],
        ),
      ),
    );
  }
}

/// Concentric elliptical orbit rings behind the planet.
class OrbitRingsPainter extends CustomPainter {
  OrbitRingsPainter({this.rotation = 0});

  final double rotation;

  static const _radii = [120.0, 145.0, 168.0];
  static const _opacities = [0.18, 0.12, 0.08];
  static const _verticalSquish = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 0.15);
    canvas.translate(-center.dx, -center.dy);

    for (var i = 0; i < _radii.length; i++) {
      final paint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: _opacities[i])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: _radii[i] * 2,
          height: _radii[i] * _verticalSquish,
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrbitRingsPainter oldDelegate) => oldDelegate.rotation != rotation;
}

/// Star field background for the orbit session screen.
class StarfieldPainter extends CustomPainter {
  StarfieldPainter({required this.stars});

  final List<StarDot> stars;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: star.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => false;
}

class StarDot {
  const StarDot({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });

  final double x;
  final double y;
  final double radius;
  final double opacity;
}

/// Fixed-seed star positions for a stable star field across rebuilds.
List<StarDot> generateStarfield({int count = 100, int seed = 42}) {
  final random = math.Random(seed);
  return List.generate(count, (_) {
    return StarDot(
      x: random.nextDouble(),
      y: random.nextDouble(),
      radius: 0.5 + random.nextDouble(),
      opacity: 0.3 + random.nextDouble() * 0.5,
    );
  });
}

/// Full-screen star field layer.
class StarfieldBackground extends StatelessWidget {
  StarfieldBackground({super.key, List<StarDot>? stars}) : stars = stars ?? generateStarfield();

  final List<StarDot> stars;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: StarfieldPainter(stars: stars),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}
