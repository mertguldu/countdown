import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

enum HomeTab { events, countUp, tally }

extension HomeTabX on HomeTab {
  String get label => switch (this) {
        HomeTab.events => 'Countdown',
        HomeTab.countUp => 'Countup',
        HomeTab.tally => 'Counter',
      };
}

class HomeTabRow extends StatelessWidget {
  const HomeTabRow({super.key, required this.active, required this.onSelect});

  final HomeTab active;
  final ValueChanged<HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: HomeTab.values
            .map((tab) => Expanded(
                  child: HomeTabItem(
                    label: tab.label,
                    selected: active == tab,
                    onTap: () => onSelect(tab),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class HomeTabItem extends StatelessWidget {
  const HomeTabItem({
    super.key,
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
        theme.textTheme.bodyMedium?.color ?? onSurface.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.titleMedium.copyWith(
                color: selected ? onSurface : muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 2,
            color: selected ? onSurface : Colors.transparent,
          ),
        ],
      ),
    );
  }
}