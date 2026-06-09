import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'countdown_display.dart';

// ── EventListItem ─────────────────────────────────────────────────────────────
//
// Layout (left → right):
//   [56×56 tile]  [title / subtitle]  [countdown]  [drag handle]
//
// The tile shows the event photo (BoxFit.cover, clipped to rounded rect) when
// one is saved, otherwise falls back to the category colour tint.

class EventListItem extends StatelessWidget {
  const EventListItem({
    super.key,
    required this.event,
    this.onTap,
  });

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted    = theme.textTheme.bodyMedium?.color ??
        onSurface.withValues(alpha: 0.5);

    final tileColor = Color(event.colorValue);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // ── Thumbnail tile ─────────────────────────────────────────────
            _Thumbnail(color: tileColor, photoPath: event.photoPath),

            const SizedBox(width: 16),

            // ── Title + subtitle ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.subtitle case final sub?) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style:
                          AppTextStyles.bodyMedium.copyWith(color: muted),
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

// ── _Thumbnail ────────────────────────────────────────────────────────────────
//
// 56×56 rounded rectangle.
// • If [photoPath] points to a readable file → show photo (BoxFit.cover).
// • Otherwise → translucent colour tint (original behaviour).

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.color, this.photoPath});

  final Color color;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    const size   = 56.0;
    const radius = BorderRadius.all(Radius.circular(12));

    if (photoPath != null && photoPath!.isNotEmpty) {
      final file = File(photoPath!);
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size, height: size,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            // Gracefully fall back to colour tile if the file is missing
            // (e.g. first launch after clearing app data).
            errorBuilder: (_, __, ___) => _colorTile(size, radius),
          ),
        ),
      );
    }

    return _colorTile(size, radius);
  }

  Widget _colorTile(double size, BorderRadius radius) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: radius,
        ),
        // TODO: Replace with CachedNetworkImage / Image.file once image-picker
        // is added to the new-event flow.
      );
}

// ── _DragHandle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: List.generate(
        3,
        (_) => Container(
          width: 18, height: 1.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}