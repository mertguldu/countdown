import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/event.dart';
import 'countdown_display.dart';
import 'countup_display.dart';

/// Unified list row for countdown and countup events.
///
/// Normal mode (right side):
///   countdown → CountdownDisplay
///   countup   → CountUpDisplay
///   tally     → nothing (handled by TallyListItem)
///
/// Edit mode, isDraggable:  drag handle replaces the right-side display.
/// Edit mode, !isDraggable: display widget still shown (finished items).
class EventListItem extends StatelessWidget {
  const EventListItem({
    super.key,
    required this.event,
    this.onTap,
    this.isEditing   = false,
    this.isDraggable = false,
    this.onDelete,
    this.eventType   = EventType.countdown,
  });

  final Event     event;
  final VoidCallback? onTap;
  final bool      isEditing;
  final bool      isDraggable;
  final VoidCallback? onDelete;
  final EventType eventType;

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final onSurf   = theme.colorScheme.onSurface;
    final mutedClr = onSurf.withValues(alpha: 0.45);
    final tileClr  = Color(event.colorValue);

    return GestureDetector(
      onTap: isEditing ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Delete button
            if (isEditing) ...[
              _DeleteButton(onTap: onDelete),
              const SizedBox(width: 12),
            ],

            // Colour swatch thumbnail
            _EventThumbnail(color: tileClr, photoPath: event.photoPath),
            const SizedBox(width: 14),

            // Title + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleMedium.copyWith(color: onSurf),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.category.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: mutedClr, letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right side
            if (isEditing && isDraggable)
              _DragHandle(color: mutedClr)
            else
              _rightDisplay(context, onSurf, mutedClr),
          ],
        ),
      ),
    );
  }

  Widget _rightDisplay(BuildContext ctx, Color onSurf, Color mutedClr) {
    return switch (eventType) {
      EventType.countdown =>
        CountdownDisplay(targetDate: event.targetDate ?? DateTime.now()),
      EventType.countup =>
        CountUpDisplay(startDate: event.targetDate ?? DateTime.now()),
      EventType.tally => const SizedBox.shrink(),
    };
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _EventThumbnail extends StatelessWidget {
  const _EventThumbnail({required this.color, this.photoPath});
  final Color color;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    const size   = 52.0;
    const radius = BorderRadius.all(Radius.circular(12));

    if (photoPath != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(photoPath!),
          width: size, height: size,
          fit: BoxFit.cover,
          // Fall back to the colour swatch if the file is missing.
          errorBuilder: (_, _, _) => _ColorSwatch(
            color: color, size: size, radius: radius),
        ),
      );
    }

    return _ColorSwatch(color: color, size: size, radius: radius);
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.size,
    required this.radius,
  });
  final Color color;
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color:         color.withValues(alpha: 0.30),
      borderRadius:  radius,
    ),
  );
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 26, height: 26,
      decoration: const BoxDecoration(
        color: Color(0xFFE53935), shape: BoxShape.circle,
      ),
      child: const Icon(Icons.remove, color: Colors.white, size: 15),
    ),
  );
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: List.generate(
      3,
      (_) => Container(
        width: 18, height: 1.5,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(1),
        ),
      ),
    ),
  );
}