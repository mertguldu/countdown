import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

// ── CountdownDisplay ──────────────────────────────────────────────────────────
//
// Shows the remaining (or elapsed) time to [targetDate] as:
//
//   57 DAYS          ← Fraunces italic + small "DAYS" superscript
//   14:22:08         ← hours:minutes:seconds in the current day, muted
//
// A private [Timer.periodic] drives a setState every second so that only this
// widget rebuilds, keeping the parent list perfectly still between ticks.

class CountdownDisplay extends StatefulWidget {
  const CountdownDisplay({super.key, required this.targetDate});

  final DateTime targetDate;

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = _compute());
    });
  }

  @override
  void didUpdateWidget(CountdownDisplay old) {
    super.didUpdateWidget(old);
    if (old.targetDate != widget.targetDate) {
      setState(() => _remaining = _compute());
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _compute() => widget.targetDate.difference(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurface.withValues(alpha: 0.5);

    // Work with the absolute duration so past events display naturally.
    final abs = _remaining.isNegative ? -_remaining : _remaining;

    final days = abs.inDays;
    final hh = (abs.inHours.remainder(24)).toString().padLeft(2, '0');
    final mm = (abs.inMinutes.remainder(60)).toString().padLeft(2, '0');
    final ss = (abs.inSeconds.remainder(60)).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Day count + DAYS superscript ─────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$days',
              style: AppTextStyles.frauncesMedium.copyWith(
                color: onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
            Padding(
              // Nudge "DAYS" to sit visually at the top of the Fraunces number.
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'DAYS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: muted,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        // ── HH:MM:SS ticker ──────────────────────────────────────────────────
        Text(
          '$hh:$mm:$ss',
          style: AppTextStyles.bodyMedium.copyWith(
            color: muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}