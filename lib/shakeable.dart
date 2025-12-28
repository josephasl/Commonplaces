import 'dart:math'; // Required for the shake rotation
import 'package:flutter/material.dart';

class Shakeable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const Shakeable({super.key, required this.child, required this.enabled});

  @override
  State<Shakeable> createState() => _ShakeableState();
}

class _ShakeableState extends State<Shakeable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Create a random offset so multiple folders don't shake in perfect unison
  final double _randomOffset = Random().nextDouble();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 90), // Faster duration = jitter
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant Shakeable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _controller.reset(); // Reset to 0 angle
    }
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
      builder: (context, child) {
        if (!widget.enabled) return widget.child;

        final double progress = 2 * (_controller.value - 0.5) + _randomOffset;

        // Max rotation angle (0.03 radians is approx 1.7 degrees)
        final double angle = 0.02 * progress;

        return Transform.rotate(angle: angle, child: widget.child);
      },
    );
  }
}
