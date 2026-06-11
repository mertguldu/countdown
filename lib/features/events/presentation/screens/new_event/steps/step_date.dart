import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../new_event_shared_widgets.dart';

class StepDate extends StatelessWidget {
  const StepDate({
    super.key, required this.isCountingDown, required this.calYear,
    required this.calMonth, required this.calDay, required this.calHour,
    required this.calMinute, required this.onPrevMonth, required this.onNextMonth,
    required this.onDaySelected, required this.onTimeTap, required this.formattedTime,
  });

  final bool isCountingDown;
  final int calYear, calMonth, calDay, calHour, calMinute;
  final VoidCallback onPrevMonth, onNextMonth, onTimeTap;
  final ValueChanged<int> onDaySelected;
  final String formattedTime;

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
            isCountingDown ? 'When is it?' : 'When did it start?',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf, fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 28),
          CalendarWidget(
            year: calYear, month: calMonth, selectedDay: calDay,
            onDaySelected: onDaySelected, onPrevMonth: onPrevMonth,
            onNextMonth: onNextMonth, minDate: isCountingDown ? DateTime.now() : null,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: onSurf.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, size: 18, color: muted),
                  const SizedBox(width: 10),
                  Text('Time', style: AppTextStyles.titleMedium.copyWith(color: onSurf)),
                  const Spacer(),
                  Text(formattedTime, style: AppTextStyles.bodyLarge.copyWith(color: muted)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16, color: muted.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}