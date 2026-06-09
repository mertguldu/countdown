// filter_pills.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/event.dart';

// ── FilterPills ───────────────────────────────────────────────────────────────
//
// Rendered as a floating frosted-glass bar by HomeScreen (Positioned, full width).
//
// Visual layers (outside → in):
//   Container       → drop shadow (must be outside the clip to be visible)
//   ClipRRect       → clips to pill shape
//   BackdropFilter  → blurs content underneath
//   Container       → translucent fill + hairline border
//   Row of _Pills   → each pill is Expanded so all three share width equally

class FilterPills extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final EventFilter selected;
  final ValueChanged<EventFilter> onSelect;

  static const double _kRadius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      // Shadow lives outside the clip so it isn't masked.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            // Increased vertical inset for a taller bar profile.
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            // mainAxisSize: max so each Expanded pill claims equal width.
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: _Pill(
                    label: 'Upcoming',
                    selected: selected == EventFilter.upcoming,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(EventFilter.upcoming);
                    },
                  ),
                ),
                Expanded(
                  child: _Pill(
                    label: 'Past',
                    selected: selected == EventFilter.past,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(EventFilter.past);
                    },
                  ),
                ),
                Expanded(
                  child: _Pill(
                    label: 'All',
                    selected: selected == EventFilter.all,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(EventFilter.all);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _Pill ─────────────────────────────────────────────────────────────────────
//
// StatefulWidget so it owns a press-scale AnimationController.
// Text is centred within the Expanded cell so all three labels stay optically
// balanced regardless of character count.

class _Pill extends StatefulWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        // Center so the highlight never stretches to fill the Expanded cell —
        // every pill's selected background is the same compact shape.
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: widget.selected ? onSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.labelLarge.copyWith(
                color: widget.selected
                    ? theme.colorScheme.surface
                    : onSurface.withValues(alpha: 0.45),
                fontWeight:
                    widget.selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      ),
    );
  }
}