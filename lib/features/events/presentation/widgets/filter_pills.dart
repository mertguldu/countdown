// filter_pills.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/event.dart';

class FilterPills extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final EventFilter selected;
  final ValueChanged<EventFilter> onSelect;

  static const double _kRadius = 20;

  // ── Date-pill helpers ─────────────────────────────────────────────────────

  bool get _dateActive =>
      selected == EventFilter.byDateAsc || selected == EventFilter.byDateDesc;

  String get _dateLabel {
    if (selected == EventFilter.byDateAsc) return 'Date ↑';
    if (selected == EventFilter.byDateDesc) return 'Date ↓';
    return 'Date';
  }

  void _onDateTap() {
    // Toggle direction when already active; select ascending when not.
    if (selected == EventFilter.byDateAsc) {
      onSelect(EventFilter.byDateDesc);
    } else {
      onSelect(EventFilter.byDateAsc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // ── Upcoming ───────────────────────────────────────────────
                Expanded(
                  child: _Pill(
                    label:    'Upcoming',
                    selected: selected == EventFilter.upcoming,
                    onTap:    () {
                      HapticFeedback.selectionClick();
                      onSelect(EventFilter.upcoming);
                    },
                  ),
                ),
                // ── Past ───────────────────────────────────────────────────
                Expanded(
                  child: _Pill(
                    label:    'Past',
                    selected: selected == EventFilter.past,
                    onTap:    () {
                      HapticFeedback.selectionClick();
                      onSelect(EventFilter.past);
                    },
                  ),
                ),
                // ── All ────────────────────────────────────────────────────
                Expanded(
                  child: _Pill(
                    label:    'All',
                    selected: selected == EventFilter.all,
                    onTap:    () {
                      HapticFeedback.selectionClick();
                      onSelect(EventFilter.all);
                    },
                  ),
                ),
                // ── Date ↑ / Date ↓ ───────────────────────────────────────
                // Tapping selects byDateAsc; tapping again toggles direction.
                Expanded(
                  child: _Pill(
                    label:    _dateLabel,
                    selected: _dateActive,
                    onTap:    () {
                      HapticFeedback.selectionClick();
                      _onDateTap();
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
    final theme     = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap:       widget.onTap,
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background — fades in/out without color interpolation
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity:  widget.selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve:    Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset:     const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Label
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve:    Curves.easeOut,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: widget.selected
                        ? onSurface
                        : onSurface.withValues(alpha: 0.45),
                    fontWeight: widget.selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  child: Text(
                    widget.label,
                    maxLines:  1,
                    softWrap:  false,
                    overflow:  TextOverflow.visible,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}