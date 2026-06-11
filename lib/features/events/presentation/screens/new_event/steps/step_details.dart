import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../new_event_constants.dart';
import '../new_event_shared_widgets.dart';

class StepDetails extends StatelessWidget {
  const StepDetails({
    super.key, required this.noteCtrl, required this.locationCtrl,
    required this.repeatOption, required this.onRepeatTap,
    required this.onImageTap, this.imagePath,
  });

  final TextEditingController noteCtrl, locationCtrl;
  final RepeatOption repeatOption;
  final VoidCallback onRepeatTap, onImageTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add some detail',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf, fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text('Everything here is optional.', style: AppTextStyles.bodyMedium.copyWith(color: muted)),
          const SizedBox(height: 28),
          DetailField(
            label: 'Photo',
            onTap: onImageTap,
            child: imagePath != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath!), width: 44, height: 44, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: onSurf.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.broken_image_outlined, size: 18, color: muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Change', style: AppTextStyles.bodyMedium.copyWith(color: muted)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: muted.withValues(alpha: 0.5)),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Add photo', style: AppTextStyles.bodyLarge.copyWith(color: muted)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: muted.withValues(alpha: 0.5)),
                    ],
                  ),
          ),
          DetailField(
            label: 'Note',
            child: TextField(
              controller: noteCtrl, textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(color: onSurf),
              decoration: InputDecoration(
                hintText: 'Add a note…',
                hintStyle: AppTextStyles.bodyLarge.copyWith(color: muted.withValues(alpha: 0.55)),
                filled: false, border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
              ),
              maxLines: 1,
            ),
          ),
          DetailField(
            label: 'Location',
            child: TextField(
              controller: locationCtrl, textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(color: onSurf),
              decoration: InputDecoration(
                hintText: 'Optional',
                hintStyle: AppTextStyles.bodyLarge.copyWith(color: muted.withValues(alpha: 0.55)),
                filled: false, border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
              ),
              maxLines: 1,
            ),
          ),
          DetailField(
            label: 'Repeat',
            onTap: onRepeatTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(repeatOption.label, style: AppTextStyles.bodyLarge.copyWith(color: muted)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16, color: muted.withValues(alpha: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}