import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

// ── CountdownDisplay ──────────────────────────────────────────────────────────
//
// Three display states:
//
//   Finished      ← target date has passed (negative remaining)
//
//   14:22:08      ← today (0 days left): Fraunces italic ticker, no DAYS label
//   or  1:01
//   or     9      ← leading-zero segments are dropped (h:mm:ss / m:ss / s)
//
//   57 DAYS       ← normal: day count (Fraunces, bottom-aligned "DAYS" label)
//    1:01         ←         compact time ticker below
//
// A private Timer.periodic drives setState every second so only this widget
// rebuilds — the parent list stays perfectly still between ticks.

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

  /// Formats a positive duration, dropping leading-zero segments.
  ///   1h 1m 1s  →  1:01:01
  ///   0h 1m 1s  →  1:01
  ///   0h 0m 9s  →  9
  String _fmt(Duration d) {
    final h = d.inHours.remainder(24);
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${_z(m)}:${_z(s)}';
    if (m > 0) return '$m:${_z(s)}';
    return '$s';
  }

  String _z(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted     = theme.textTheme.bodyMedium?.color ??
        onSurface.withValues(alpha: 0.5);

    // ── Finished: target has passed ───────────────────────────────────────────
    if (_remaining.isNegative || _remaining == Duration.zero) {
      return Text(
        // TODO: swap string if you prefer e.g. "It happened!" or "Done ✓"
        'Finished',
        style: AppTextStyles.bodyMedium.copyWith(
          color: muted,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final days    = _remaining.inDays;
    final timeStr = _fmt(_remaining);

    // ── Today (0 days left): large Fraunces time ticker ───────────────────────
    if (days == 0) {
      return Text(
        timeStr,
        style: AppTextStyles.frauncesMedium.copyWith(
          color: onSurface,
          fontStyle: FontStyle.italic,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    // ── Normal: day count + compact time ticker ───────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // left-align both rows
      mainAxisSize: MainAxisSize.min,
      children: [
        // Day count with bottom-aligned "DAYS" label
        Row(
          crossAxisAlignment: CrossAxisAlignment.end, // bottom-align label
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$days',
              style: AppTextStyles.frauncesMedium.copyWith(
                color: onSurface,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4), // gap between number and label
            Padding(
              padding: const EdgeInsets.only(bottom: 3), // fine-tune baseline
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
        // Compact time ticker — no leading-zero segments
        Text(
          timeStr,
          style: AppTextStyles.bodyMedium.copyWith(
            color: muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}