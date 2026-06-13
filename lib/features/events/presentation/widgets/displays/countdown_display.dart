import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_text_styles.dart';

/// Live per-second countdown timer display.
/// Takes a guaranteed non-null [targetDate] (callers use event.targetDate!).
class CountdownDisplay extends StatefulWidget {
  const CountdownDisplay({super.key, required this.targetDate});
  final DateTime targetDate;

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  late Timer  _timer;
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

  /// hh:mm:ss without leading zeros on the leftmost unit.
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
    final theme    = Theme.of(context);
    final onSurf   = theme.colorScheme.onSurface;
    final mutedClr = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    // Finished
    if (_remaining.isNegative || _remaining == Duration.zero) {
      return Text(
        'Finished',
        style: AppTextStyles.bodyMedium.copyWith(
          color: mutedClr, fontStyle: FontStyle.italic,
        ),
      );
    }

    final days    = _remaining.inDays;
    final timeStr = _fmt(_remaining);

    // Same day — show only time ticker
    if (days == 0) {
      return Text(
        timeStr,
        style: AppTextStyles.frauncesMedium.copyWith(
          color: onSurf,
          fontStyle: FontStyle.italic,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    // Multiple days
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$days',
              style: AppTextStyles.frauncesMedium.copyWith(
                color: onSurf, fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'DAYS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: mutedClr, letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        Text(
          timeStr,
          style: AppTextStyles.bodyMedium.copyWith(
            color: mutedClr,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}