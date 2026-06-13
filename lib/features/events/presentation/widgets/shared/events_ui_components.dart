import 'package:flutter/material.dart';
import '../../../../../core/theme/app_text_styles.dart';

class EditGroupHeader extends StatelessWidget {
  const EditGroupHeader({
    super.key,
    required this.category,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String category;
  final bool canMoveUp, canMoveDown;
  final VoidCallback onMoveUp, onMoveDown;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final muted = onSurf.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 6),
      child: Row(
        children: [
          Text(category.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                  color: muted,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          MoveBtn(Icons.keyboard_arrow_up_rounded, canMoveUp, onMoveUp, onSurf),
          MoveBtn(Icons.keyboard_arrow_down_rounded, canMoveDown, onMoveDown, onSurf),
        ],
      ),
    );
  }
}

class MoveBtn extends StatelessWidget {
  const MoveBtn(this.icon, this.enabled, this.onTap, this.activeColor, {super.key});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon,
              size: 22,
              color: enabled
                  ? activeColor
                  : activeColor.withValues(alpha: 0.2)),
        ),
      );
}

class CategoryHeader extends StatelessWidget {
  const CategoryHeader(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
              color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
    );
  }
}

class EventsDivider extends StatelessWidget {
  const EventsDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
      );
}

class EmptyEventsState extends StatelessWidget {
  const EmptyEventsState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.40);
    return Center(
      child: Text(message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.6)),
    );
  }
}

class EventsErrorState extends StatelessWidget {
  const EventsErrorState(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('Error: $message',
            style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.error)),
      );
}