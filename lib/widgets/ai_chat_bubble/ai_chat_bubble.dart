import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenverse/widgets/ai_chat_bubble/chat_full_screen.dart';
import 'package:zenverse/widgets/ai_chat_bubble/gemini_chat_service.dart';
import 'package:zenverse/widgets/ai_chat_bubble/gemini_config.dart';

/// Add on the Home screen only, e.g. inside a [Stack] over your home body.
class AiChatBubble extends StatefulWidget {
  const AiChatBubble({
    super.key,
    this.apiKey,
    this.model = GeminiChatService.defaultModel,
    this.assistantTitle = 'Zen AI',
    this.enabled = true,
  });

  /// Optional override; when null, [GeminiConfig.apiKey] from `.env` is used.
  final String? apiKey;

  final String model;
  final String assistantTitle;
  final bool enabled;

  static const _prefX = 'ai_chat_bubble_pos_x';
  static const _prefY = 'ai_chat_bubble_pos_y';
  static const _fabSize = 56.0;
  static const _fabMargin = 16.0;

  /// Movement below this distance (px) counts as a tap, not a drag.
  static const tapSlop = 10.0;

  @override
  State<AiChatBubble> createState() => _AiChatBubbleState();
}

class _AiChatBubbleState extends State<AiChatBubble> with SingleTickerProviderStateMixin {
  Offset? _position;
  bool _chatOpen = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  GeminiChatService? _gemini;

  String get _resolvedApiKey => (widget.apiKey ?? GeminiConfig.apiKey).trim();

  bool get _hasApiKey => _resolvedApiKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (_hasApiKey) {
      _gemini = GeminiChatService(apiKey: _resolvedApiKey, model: widget.model);
    }
    _loadPosition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gemini?.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(AiChatBubble._prefX);
    final y = prefs.getDouble(AiChatBubble._prefY);
    if (!mounted) return;
    setState(() {
      if (x != null && y != null) {
        _position = Offset(x, y);
      }
    });
  }

  Future<void> _savePosition(Offset pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AiChatBubble._prefX, pos.dx);
    await prefs.setDouble(AiChatBubble._prefY, pos.dy);
  }

  Offset _defaultPosition(Size screen) {
    return Offset(
      screen.width - AiChatBubble._fabSize - AiChatBubble._fabMargin,
      screen.height - AiChatBubble._fabSize - 140,
    );
  }

  Offset _clampPosition(Offset pos, Size screen) {
    final maxX = math.max(0.0, screen.width - AiChatBubble._fabSize);
    final maxY = math.max(0.0, screen.height - AiChatBubble._fabSize);
    return Offset(
      pos.dx.clamp(0.0, maxX),
      pos.dy.clamp(0.0, maxY),
    );
  }

  Future<void> _openChat() async {
    if (!_hasApiKey || _gemini == null) {
      Get.snackbar(
        'Zen AI',
        'Gemini API key missing. Copy .env.example to .env and set GEMINI_API_KEY.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    setState(() => _chatOpen = true);
    _pulseController.stop();

    await Get.to<void>(
      () => ChatFullScreen(
        assistantTitle: widget.assistantTitle,
        geminiService: _gemini!,
      ),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 350),
    );

    if (!mounted) return;
    setState(() => _chatOpen = false);
    _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        if (screen.width <= 0 || screen.height <= 0) return const SizedBox.shrink();

        final pos = _clampPosition(_position ?? _defaultPosition(screen), screen);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: _FloatingButton(
                pulseAnimation: _chatOpen ? null : _pulseAnimation,
                onTap: _openChat,
                onDragUpdate: (delta) {
                  setState(() {
                    final base = _position ?? _defaultPosition(screen);
                    _position = _clampPosition(base + delta, screen);
                  });
                },
                onDragEnd: () {
                  if (_position != null) _savePosition(_position!);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Draggable circular FAB: short tap opens chat; drag beyond [AiChatBubble.tapSlop] moves it.
class _FloatingButton extends StatefulWidget {
  const _FloatingButton({
    required this.onTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.pulseAnimation,
  });

  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final Animation<double>? pulseAnimation;

  @override
  State<_FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<_FloatingButton> {
  Offset _panTotal = Offset.zero;
  bool _isDragging = false;

  void _resetGesture() {
    _panTotal = Offset.zero;
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget fab = Material(
      elevation: 6,
      shadowColor: scheme.primary.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      color: scheme.primaryContainer,
      child: SizedBox(
        width: AiChatBubble._fabSize,
        height: AiChatBubble._fabSize,
        child: Icon(Icons.smart_toy_rounded, color: scheme.onPrimaryContainer, size: 28),
      ),
    );

    if (widget.pulseAnimation != null) {
      fab = ScaleTransition(scale: widget.pulseAnimation!, child: fab);
    }

    // Single GestureDetector: pan tracks movement; tap if total movement < tapSlop.
    // No InkWell/onTap here — pan would steal those events.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _resetGesture(),
      onPanUpdate: (details) {
        _panTotal += details.delta;
        if (!_isDragging && _panTotal.distance >= AiChatBubble.tapSlop) {
          _isDragging = true;
        }
        if (_isDragging) {
          widget.onDragUpdate(details.delta);
        }
      },
      onPanEnd: (_) {
        if (_isDragging) {
          widget.onDragEnd();
        } else {
          widget.onTap();
        }
        _resetGesture();
      },
      onPanCancel: _resetGesture,
      child: fab,
    );
  }
}
