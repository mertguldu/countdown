import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'countdown_display.dart';

class EventListItem extends StatelessWidget {
  const EventListItem({
    super.key,
    required this.event,
    this.onTap,
    this.isEditing   = false,
    this.isDraggable = false,   // true only for active-tab items in edit mode
    this.onDelete,
  });

  final Event event;
  final VoidCallback? onTap;
  final bool isEditing;
  final bool isDraggable;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted     = theme.textTheme.bodyMedium?.color ??
        onSurface.withValues(alpha: 0.5);
    final tileColor = Color(event.colorValue);

    return InkWell(
      onTap: isEditing ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [

            // ── Delete button (edit mode only) ─────────────────────────────
            if (isEditing) ...[
              _DeleteButton(onTap: onDelete),
              const SizedBox(width: 12),
            ],

            // ── Thumbnail ──────────────────────────────────────────────────
            _Thumbnail(color: tileColor, photoPath: event.photoPath),
            const SizedBox(width: 16),

            // ── Title + subtitle / category ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleMedium.copyWith(color: onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.category.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: muted, letterSpacing: 1.2,
                      ),
                    ),
                  ] else if (event.subtitle case final sub?) ...[
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

            // ── Right side ─────────────────────────────────────────────────
            // Drag handle only when the item is actively draggable.
            // Everything else (normal mode, finished-tab edit mode) shows
            // the countdown — which naturally reads "Finished" for past events.
            if (isEditing && isDraggable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: _DragHandle(color: muted),
              )
            else
              CountdownDisplay(targetDate: event.targetDate),
          ],
        ),
      ),
    );
  }
}

// ── _DeleteButton ─────────────────────────────────────────────────────────────

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26, height: 26,
        decoration: const BoxDecoration(
          color: Color(0xFFE53935),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.remove, color: Colors.white, size: 16),
      ),
    );
  }
}

// ── _Thumbnail ────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.color, this.photoPath});
  final Color color;
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    const size   = 56.0;
    const radius = BorderRadius.all(Radius.circular(12));

    if (photoPath != null && photoPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size, height: size,
          child: Image.file(
            File(photoPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _colorTile(size, radius),
          ),
        ),
      );
    }
    return _colorTile(size, radius);
  }

  Widget _colorTile(double size, BorderRadius radius) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: radius,
        ),
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