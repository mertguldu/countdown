import 'package:flutter/material.dart';

/// Wraps a pill bar so all three can overlap in a Stack — only the active
/// one is visible and interactive. Includes the horizontal padding so all
/// three bars stay perfectly aligned.
class PillLayer extends StatelessWidget {
  const PillLayer({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: child,
          ),
        ),
      );
}