// new_event_shared_widgets.dart
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'new_event_constants.dart';

class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onBack,
    required this.onClose,
  });

  final int step, totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: AnimatedOpacity(
                opacity:  onBack != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 26,
                  color: onSurf,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final filled = i < step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? onSurf : Colors.transparent,
                      border: Border.all(
                        color: onSurf.withValues(alpha: filled ? 1.0 : 0.28),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                iconSize: 20,
                color: onSurf,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CtaArea extends StatelessWidget {
  const CtaArea({
    super.key,
    required this.isLastStep,
    required this.isSkippable,
    required this.saving,
    required this.onCta,
    required this.onSkip,
  });

  final bool isLastStep, isSkippable, saving;
  final VoidCallback onCta, onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: saving ? null : onCta,
              style: FilledButton.styleFrom(
                backgroundColor: onSurf,
                foregroundColor: theme.colorScheme.surface,
                disabledBackgroundColor: onSurf.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              child: saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.colorScheme.surface),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isLastStep ? 'Create event' : 'Continue'),
                        if (!isLastStep) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: isSkippable
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: GestureDetector(
            onTap: onSkip,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
              child: Text('Skip this step',
                  style: AppTextStyles.bodyMedium.copyWith(color: muted)),
            ),
          ),
          secondChild: const SizedBox(height: 20),
        ),
      ],
    );
  }
}

class DetailField extends StatelessWidget {
  const DetailField({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    Widget row = Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: muted.withValues(alpha: 0.14), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );

    if (onTap != null) {
      row = GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
    }
    return row;
  }
}

class CalendarWidget extends StatelessWidget {
  const CalendarWidget({
    super.key,
    required this.year,
    required this.month,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPrevMonth,
    required this.onNextMonth,
    this.minDate,
  });

  final int year, month, selectedDay;
  final ValueChanged<int> onDaySelected;
  final VoidCallback onPrevMonth, onNextMonth;
  final DateTime? minDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final surfCol = theme.colorScheme.surface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);
    final now = DateTime.now();

    final firstOffset = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final rowCount = ((firstOffset + daysInMonth) / 7).ceil();

    final todayStart = minDate == null
        ? null
        : DateTime(minDate!.year, minDate!.month, minDate!.day);

    List<Widget> buildRows() {
      final rows = <Widget>[];
      for (var row = 0; row < rowCount; row++) {
        final cells = <Widget>[];
        for (var col = 0; col < 7; col++) {
          final idx = row * 7 + col;
          if (idx < firstOffset || idx >= firstOffset + daysInMonth) {
            cells.add(const Expanded(child: SizedBox(height: 36)));
            continue;
          }
          final day = idx - firstOffset + 1;
          final cellDate = DateTime(year, month, day);
          final isDisabled = todayStart != null && cellDate.isBefore(todayStart);
          final isSel = day == selectedDay;
          final isToday = now.year == year && now.month == month && now.day == day;

          cells.add(Expanded(
            child: isDisabled
                ? Container(
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                    child: Center(
                      child: Text('$day',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: onSurf.withValues(alpha: 0.2))),
                    ),
                  )
                : GestureDetector(
                    onTap: () => onDaySelected(day),
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? onSurf : Colors.transparent,
                        border: isToday && !isSel
                            ? Border.all(
                                color: onSurf.withValues(alpha: 0.35),
                                width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text('$day',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSel ? surfCol : onSurf,
                              fontWeight: isSel ? FontWeight.w500 : FontWeight.w400,
                            )),
                      ),
                    ),
                  ),
          ));
        }
        if (row > 0) rows.add(const SizedBox(height: 2));
        rows.add(Row(children: cells));
      }
      return rows;
    }

    return Container(
      decoration: BoxDecoration(
        color: onSurf.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              CalNavBtn(icon: Icons.chevron_left, onTap: onPrevMonth),
              Expanded(
                child: Text(
                  '${kMonthNames[month - 1]} $year',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium.copyWith(color: onSurf),
                ),
              ),
              CalNavBtn(icon: Icons.chevron_right, onTap: onNextMonth),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(d,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(color: muted)),
                      ),
                    ))
                .toList(),
          ),
          ...buildRows(),
        ],
      ),
    );
  }
}

class CalNavBtn extends StatelessWidget {
  const CalNavBtn({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
          width: 32, height: 32, child: Icon(icon, color: muted, size: 20)),
    );
  }
}

class RepeatSheet extends StatelessWidget {
  const RepeatSheet({super.key, required this.selected, required this.onSelect});
  final RepeatOption selected;
  final ValueChanged<RepeatOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: RepeatOption.values.map((opt) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(opt.label,
                  style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
              trailing: opt == selected
                  ? Icon(Icons.check, color: onSurf, size: 20)
                  : null,
              onTap: () => onSelect(opt),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class DoneView extends StatelessWidget {
  const DoneView({super.key, required this.name, required this.onDone});
  final String name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 52, color: onSurf),
          const SizedBox(height: 24),
          Text(
            '"$name" was created',
            textAlign: TextAlign.center,
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 28, color: onSurf,
              fontStyle: FontStyle.italic, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "It's been added to your list and your widget will update shortly.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: onSurf,
                foregroundColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              child: const Text('Back to moments'),
            ),
          ),
        ],
      ),
    );
  }
}