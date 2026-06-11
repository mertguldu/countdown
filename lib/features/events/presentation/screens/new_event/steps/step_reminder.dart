import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../new_event_constants.dart';

class StepReminder extends StatelessWidget {
  const StepReminder({
    super.key, required this.isCountingDown, required this.selected, required this.onSelect,
    required this.customWeeks, required this.customDays, required this.customHours,
    required this.customMins, required this.onWeeksChanged, required this.onDaysChanged,
    required this.onHoursChanged, required this.onMinsChanged,
  });

  final bool isCountingDown;
  final Reminder selected;
  final ValueChanged<Reminder> onSelect;
  final int customWeeks, customDays, customHours, customMins;
  final ValueChanged<int> onWeeksChanged, onDaysChanged, onHoursChanged, onMinsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);
    final options = isCountingDown ? Reminder.values : [Reminder.custom];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Want a reminder?',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf, fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isCountingDown ? "We'll notify you before your moment arrives." : "We'll send a notification after it begins.",
            style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ...options.map((opt) {
            final isSel = opt == selected;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(opt);
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
                          duration: const Duration(milliseconds: 200), width: 22, height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? onSurf : muted.withValues(alpha: 0.38), width: 1.5),
                          ),
                          child: isSel ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: onSurf))) : null,
                        ),
                        const SizedBox(width: 16),
                        Text(opt.label, style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
                      ],
                    ),
                  ),
                ),
                if (opt == Reminder.custom && isSel)
                  CustomReminderBoxes(
                    isCountingDown: isCountingDown, weeks: customWeeks, days: customDays,
                    hours: customHours, mins: customMins, onWeeksChanged: onWeeksChanged,
                    onDaysChanged: onDaysChanged, onHoursChanged: onHoursChanged, onMinsChanged: onMinsChanged,
                  ),
              ],
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class CustomReminderBoxes extends StatelessWidget {
  const CustomReminderBoxes({
    super.key, required this.isCountingDown, required this.weeks, required this.days,
    required this.hours, required this.mins, required this.onWeeksChanged,
    required this.onDaysChanged, required this.onHoursChanged, required this.onMinsChanged,
  });

  final bool isCountingDown;
  final int weeks, days, hours, mins;
  final ValueChanged<int> onWeeksChanged, onDaysChanged, onHoursChanged, onMinsChanged;

  String get _summary {
    final parts = <String>[];
    if (weeks == 1) {
      parts.add('1 week');
    } else if (weeks > 1) {
      parts.add('$weeks weeks');
    }
    if (days == 1) {
      parts.add('1 day');
    } else if (days > 1) {
      parts.add('$days days');
    }
    if (hours == 1) {
      parts.add('1 hour');
    } else if (hours > 1) {
      parts.add('$hours hours');
    }
    if (mins == 1) {
      parts.add('1 min');
    } else if (mins > 1) {
      parts.add('$mins mins');
    }

    if (parts.isEmpty) return isCountingDown ? 'No reminder set' : 'No notification set';

    final String duration;
    if (parts.length == 1) { duration = parts.first; }
    else if (parts.length == 2) { duration = '${parts[0]} and ${parts[1]}'; }
    else { duration = '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}'; }

    return isCountingDown ? '$duration before' : '$duration after';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);
    final hasValue = weeks > 0 || days > 0 || hours > 0 || mins > 0;
    final summary = _summary;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: hasValue ? onSurf.withValues(alpha: 0.07) : onSurf.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim, child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              child: Text(
                summary, key: ValueKey(summary), textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  color: hasValue ? onSurf : muted, fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          StepperRow(label: 'Weeks', value: weeks, onChanged: onWeeksChanged, max: 52),
          StepperRow(label: 'Days', value: days, onChanged: onDaysChanged, max: 364),
          StepperRow(label: 'Hours', value: hours, onChanged: onHoursChanged, max: 23),
          StepperRow(label: 'Mins', value: mins, onChanged: onMinsChanged, max: 59),
        ],
      ),
    );
  }
}

class StepperRow extends StatelessWidget {
  const StepperRow({super.key, required this.label, required this.value, required this.onChanged, this.max = 99});

  final String label;
  final int value, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: muted.withValues(alpha: 0.12), width: 0.5)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
          ),
          const Spacer(),
          StepperBtn(
            icon: Icons.remove, enabled: value > 0,
            onTap: () { if (value > 0) { HapticFeedback.selectionClick(); onChanged(value - 1); } },
          ),
          SizedBox(
            width: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim, child: ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              child: Text(
                '$value', key: ValueKey(value), textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  color: value > 0 ? onSurf : muted.withValues(alpha: 0.4), fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          ),
          StepperBtn(
            icon: Icons.add, enabled: value < max,
            onTap: () { if (value < max) { HapticFeedback.selectionClick(); onChanged(value + 1); } },
          ),
        ],
      ),
    );
  }
}

class StepperBtn extends StatelessWidget {
  const StepperBtn({super.key, required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: enabled ? onTap : null, behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180), width: 30, height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? onSurf.withValues(alpha: 0.08) : Colors.transparent),
          child: Icon(icon, size: 15, color: enabled ? onSurf : muted.withValues(alpha: 0.22)),
        ),
      ),
    );
  }
}