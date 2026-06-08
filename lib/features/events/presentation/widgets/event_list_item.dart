import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'countdown_display.dart';

// ── EventListItem ─────────────────────────────────────────────────────────────
//
// Layout (left → right):
//   [56×56 colour tile]  [title / subtitle]  [countdown]  [drag handle]
//
// The countdown widget manages its own Timer — this widget is purely stateless.

class EventListItem extends StatelessWidget {
  const EventListItem({
    super.key,
    required this.event,
    this.onTap,
  });

  final Event event;

  /// Called when the row body is tapped (navigates to event detail).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ??
        onSurface.withValues(alpha: 0.5);

    // Reconstruct the Flutter Color from the stored ARGB int.
    final tileColor = Color(event.colorValue);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // ── Colour thumbnail ───────────────────────────────────────────
            _ColorTile(color: tileColor),

            const SizedBox(width: 16),

            // ── Title + subtitle ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.subtitle case final sub?) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: AppTextStyles.bodyMedium.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Live countdown ─────────────────────────────────────────────
            CountdownDisplay(targetDate: event.targetDate),

            const SizedBox(width: 12),

            // ── Drag handle ────────────────────────────────────────────────
            _DragHandle(color: muted),
          ],
        ),
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        // A translucent wash of the category colour keeps thumbnails from
        // overpowering the dark background while still feeling distinct.
        color: color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      // TODO: Replace with CachedNetworkImage / Image.file once image-picker
      // is added to the new-event flow.
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Three short horizontal lines (≡), matching the design glyph.
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: List.generate(
        3,
        (_) => Container(
          width: 18,
          height: 1.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}