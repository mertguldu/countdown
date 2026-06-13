import 'package:flutter/material.dart';

import '../../../../../core/theme/app_text_styles.dart';

// ── FrauncesNumber ────────────────────────────────────────────────────────────
//
// Renders a number string in the Fraunces typeface.
//
// Use this widget anywhere a large numeric value is displayed (countdown days,
// counter totals, stats). CountdownDisplay uses it internally.
//
// Usage:
//   FrauncesNumber(number: '57', size: FrauncesSize.medium)

enum FrauncesSize { hero, large, medium }

class FrauncesNumber extends StatelessWidget {
  const FrauncesNumber({
    super.key,
    required this.number,
    this.size = FrauncesSize.medium,
    this.color,
    this.italic = false,
  });

  final String number;
  final FrauncesSize size;
  final Color? color;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final base = switch (size) {
      FrauncesSize.hero   => AppTextStyles.frauncesHero,
      FrauncesSize.large  => AppTextStyles.frauncesLarge,
      FrauncesSize.medium => AppTextStyles.frauncesMedium,
    };

    final resolved = base.copyWith(
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );

    return Text(number, style: resolved);
  }
}