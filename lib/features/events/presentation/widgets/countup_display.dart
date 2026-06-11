import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Live count-up display — mirrors CountdownDisplay logic but measures elapsed
/// time since [startDate].
/// If [startDate] is still in the future, shows "Starts in X d" / "Starting soon".
class CountUpDisplay extends StatefulWidget {
  const CountUpDisplay({super.key, required this.startDate});
  final DateTime startDate;

  @override
  State<CountUpDisplay> createState() => _CountUpDisplayState();
}

class _CountUpDisplayState extends State<CountUpDisplay> {
  late Timer    _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = _compute());
    });
  }

  @override
  void didUpdateWidget(CountUpDisplay old) {
    super.didUpdateWidget(old);
    if (old.startDate != widget.startDate) {
      setState(() => _elapsed = _compute());
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _compute() => DateTime.now().difference(widget.startDate);

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

    // Start date is still in the future
    if (_elapsed.isNegative) {
      final remaining = widget.startDate.difference(DateTime.now());
      final days = remaining.inDays;
      return Text(
        days > 0 ? 'Starts in $days d' : 'Starting soon',
        style: AppTextStyles.bodyMedium.copyWith(
          color: mutedClr, fontStyle: FontStyle.italic,
        ),
      );
    }

    final days    = _elapsed.inDays;
    final timeStr = _fmt(_elapsed);

    // Under a day — show just the ticker
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

    // Days + time below
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