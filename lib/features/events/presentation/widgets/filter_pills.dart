import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/event.dart';

// ── FilterPills ───────────────────────────────────────────────────────────────
//
// Renders the Upcoming | Past | All row from the design:
//
//   ┌─────────────┐
//   │  Upcoming   │   Past   All
//   └─────────────┘
//
// "Upcoming" uses a filled white pill; "Past" and "All" are plain text tabs.
// All three are equally tappable and animate between states.

class FilterPills extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final EventFilter selected;
  final ValueChanged<EventFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilledPill(
          label: 'Upcoming',
          selected: selected == EventFilter.upcoming,
          onTap: () => onSelect(EventFilter.upcoming),
        ),
        const SizedBox(width: 4),
        _PlainPill(
          label: 'Past',
          selected: selected == EventFilter.past,
          onTap: () => onSelect(EventFilter.past),
        ),
        const SizedBox(width: 4),
        _PlainPill(
          label: 'All',
          selected: selected == EventFilter.all,
          onTap: () => onSelect(EventFilter.all),
        ),
      ],
    );
  }
}

// ── Filled pill ───────────────────────────────────────────────────────────────
// White background when selected; transparent (invisible) when not.

class _FilledPill extends StatelessWidget {
  const _FilledPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodyMedium?.color ?? Colors.white.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? Colors.black : muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Plain text pill ───────────────────────────────────────────────────────────
// No background — just a text brightness shift between selected / unselected.

class _PlainPill extends StatelessWidget {
  const _PlainPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted =
        theme.textTheme.bodyMedium?.color ?? onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? onSurface : muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}