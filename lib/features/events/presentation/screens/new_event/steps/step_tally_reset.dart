import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../domain/event.dart';
import '../../../../../../core/theme/app_text_styles.dart';

class StepTallyReset extends StatelessWidget {
  const StepTallyReset({super.key, required this.selected, required this.onSelect});

  final ResetPeriod selected;
  final ValueChanged<ResetPeriod> onSelect;

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
            'Should it reset?',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf, fontStyle: FontStyle.italic,
              height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose how often this counter resets to zero.',
            style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ...ResetPeriod.values.map((period) {
            final isSel = period == selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(period);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: muted.withValues(alpha: 0.14), width: 0.5)),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? onSurf : muted.withValues(alpha: 0.38), width: 1.5,
                        ),
                      ),
                      child: isSel
                          ? Center(
                              child: Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: onSurf)))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            period.pickerLabel,
                            style: AppTextStyles.bodyLarge.copyWith(color: onSurf),
                          ),
                          if (period != ResetPeriod.never)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                period.displayLabel,
                                style: AppTextStyles.bodyMedium.copyWith(color: muted),
                              ),
                            ),
                        ],
                      ),
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