import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/event.dart';

// ── FilterPills (countdown) ───────────────────────────────────────────────────

class FilterPills extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final EventFilter                selected;
  final ValueChanged<EventFilter>  onSelect;

  static const double _kRadius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.12),
            blurRadius: 28, offset: const Offset(0, 8),
          ),
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
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
                Expanded(
                  child: _Pill(
                    label:    'Upcoming',
                    selected: selected == EventFilter.upcoming,
                    onTap:    () => _pick(EventFilter.upcoming),
                  ),
                ),
                Expanded(
                  child: _Pill(
                    label:    'Past',
                    selected: selected == EventFilter.past,
                    onTap:    () => _pick(EventFilter.past),
                  ),
                ),
                Expanded(
                  child: _Pill(
                    label:    'All',
                    selected: selected == EventFilter.all,
                    onTap:    () => _pick(EventFilter.all),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pick(EventFilter f) {
    HapticFeedback.selectionClick();
    onSelect(f);
  }
}

// ── CountUpFilterPills ────────────────────────────────────────────────────────

class CountUpFilterPills extends StatelessWidget {
  const CountUpFilterPills({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final CountUpFilter                selected;
  final ValueChanged<CountUpFilter>  onSelect;

  static const double _kRadius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.12),
            blurRadius: 28, offset: const Offset(0, 8),
          ),
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
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
              children: CountUpFilter.values
                  .map((f) => Expanded(
                        child: _Pill(
                          label:    f.label,
                          selected: selected == f,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(f);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── TallyViewPills ────────────────────────────────────────────────────────────

class TallyViewPills extends StatelessWidget {
  const TallyViewPills({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final TallyViewMode                selected;
  final ValueChanged<TallyViewMode>  onSelect;

  static const double _kRadius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.12),
            blurRadius: 28, offset: const Offset(0, 8),
          ),
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
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
              children: TallyViewMode.values
                  .map((m) => Expanded(
                        child: _Pill(
                          label:    m.label,
                          selected: selected == m,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(m);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared pill ───────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color:        selected ? scheme.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w500,
            color: selected ? scheme.surface : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}