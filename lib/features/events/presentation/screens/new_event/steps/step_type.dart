import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../new_event_constants.dart';
import '../../../../domain/event.dart';
import '../../../../../../core/theme/app_text_styles.dart';

class StepType extends StatelessWidget {
  const StepType({super.key, required this.selected, required this.onChanged});

  final EventType selected;
  final ValueChanged<EventType> onChanged;

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
            'How should it\ncount?',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf, fontStyle: FontStyle.italic,
              height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 28),
          ...kEventTypeOptions.map((opt) {
            final isSel = opt.type == selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(opt.type);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSel ? onSurf.withValues(alpha: 0.06) : Colors.transparent,
                  border: Border.all(
                    color: isSel ? onSurf.withValues(alpha: 0.18) : muted.withValues(alpha: 0.14),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSel ? onSurf.withValues(alpha: 0.10) : onSurf.withValues(alpha: 0.05),
                      ),
                      child: Icon(opt.icon, size: 20, color: isSel ? onSurf : muted),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.label, style: AppTextStyles.titleMedium.copyWith(
                              color: onSurf, fontWeight: isSel ? FontWeight.w600 : FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(opt.desc, style: AppTextStyles.bodyMedium.copyWith(color: muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? onSurf : muted.withValues(alpha: 0.38),
                          width: 1.5,
                        ),
                      ),
                      child: isSel ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: onSurf))) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}