import 'package:flutter/material.dart';

/// Animated three-dot indicator shown while the AI is "typing".
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final phase = (_controller.value + i / 3) % 1.0;
            final opacity = 0.35 + 0.65 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: opacity.clamp(0.35, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
