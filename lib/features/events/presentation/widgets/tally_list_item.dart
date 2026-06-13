import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/database.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Row item for a tally counter.
///
/// Normal mode:  [Thumbnail] Title / resetLabel   [−] [count] [+]
/// Edit mode:    [Delete] [Thumbnail] Title / category   [DragHandle]
class TallyListItem extends StatelessWidget {
  const TallyListItem({
    super.key,
    required this.event,
    this.isEditing   = false,
    this.isDraggable = false,
    this.onDelete,
    this.onIncrement,
    this.onDecrement,
  });

  final Event event;
  final bool isEditing;
  final bool isDraggable;
  final VoidCallback? onDelete;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final onSurf   = theme.colorScheme.onSurface;
    final mutedClr = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final tileClr  = Color(event.colorValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Delete button (edit mode only)
          if (isEditing) ...[
            _DeleteButton(onTap: onDelete),
            const SizedBox(width: 12),
          ],

          // Thumbnail swatch
          _Thumbnail(color: tileClr, photoPath: event.photoPath),
          const SizedBox(width: 14),

          // Title + subtitle
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
                )
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right side
          if (isEditing && isDraggable)
            _DragHandle(color: mutedClr)
          else if (!isEditing)
            _TallyCounter(
              count:       event.tallyCount,
              onDecrement: onDecrement,
              onIncrement: onIncrement,
            ),
        ],
      ),
    );
  }
}

// ── Counter buttons ───────────────────────────────────────────────────────────

class _TallyCounter extends StatelessWidget {
  const _TallyCounter({
    required this.count,
    this.onDecrement,
    this.onIncrement,
  });

  final int count;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final onSurf   = Theme.of(context).colorScheme.onSurface;
    final mutedClr = onSurf.withValues(alpha: 0.25);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CountBtn(
          icon:  Icons.remove,
          onTap: count > 0 ? onDecrement : null,
          color: count > 0 ? onSurf : mutedClr,
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: AppTextStyles.frauncesMedium.copyWith(
              color: onSurf, fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _CountBtn(
          icon:  Icons.add,
          onTap: onIncrement,
          color: onSurf,
        ),
      ],
    );
  }
}

class _CountBtn extends StatelessWidget {
  const _CountBtn({
    required this.icon,
    required this.color,
    this.onTap,
  });

  final IconData  icon;
  final Color     color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null
              ? onSurf.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.color, this.photoPath});
  final Color   color;
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
          errorBuilder: (_, _, _) => _swatch(size, radius),
        ),
      );
    }

    return _swatch(size, radius);
  }

  Widget _swatch(double size, BorderRadius radius) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.30),
      borderRadius: radius,
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