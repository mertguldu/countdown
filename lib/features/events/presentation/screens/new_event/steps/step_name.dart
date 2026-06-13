import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../new_event_constants.dart';

class StepName extends StatelessWidget {
  const StepName({
    super.key,
    required this.nameCtrl,
    required this.customCategoryCtrl,
    required this.category,
    required this.onCategoryChanged,
    required this.hasError,
  });

  final TextEditingController nameCtrl;
  final TextEditingController customCategoryCtrl;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);
    final error = theme.colorScheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title
          Text(
            "What's your\nmoment?",
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32,
              color: onSurf,
              fontStyle: FontStyle.italic,
              height: 1.18,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 36),

          // 2. Main Moment Name Field
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 26,
              color: onSurf,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.3,
            ),
            decoration: InputDecoration(
              hintText: 'Give it a name…',
              hintStyle: AppTextStyles.frauncesMedium.copyWith(
                fontSize: 26,
                color: muted.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
              filled: false,
              border: UnderlineInputBorder(
                  borderSide: BorderSide(color: muted.withValues(alpha: 0.28), width: 1.5)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: hasError ? error : muted.withValues(alpha: 0.28), width: 1.5)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: hasError ? error : onSurf, width: 1.5)),
              contentPadding: const EdgeInsets.only(top: 10, bottom: 14),
            ),
            textInputAction: TextInputAction.next, // Changed to next for better structural flow
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: hasError ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Give your moment a name to continue.',
                style: AppTextStyles.labelSmall.copyWith(color: error),
              ),
            ),
            secondChild: const SizedBox(height: 0),
          ),

          // 3. Custom Category Input (Placed right under the main title items)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: category == 'Other' ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextField(
                controller: customCategoryCtrl,
                autofocus: true, // Immediately keyboard-focuses when revealed
                style: AppTextStyles.bodyLarge.copyWith(color: onSurf),
                decoration: InputDecoration(
                  hintText: 'What kind of moment?',
                  hintStyle: AppTextStyles.bodyLarge.copyWith(color: muted.withValues(alpha: 0.45)),
                  filled: false,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: muted.withValues(alpha: 0.28), width: 1.5),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
                ),
                textInputAction: TextInputAction.done,
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
          const SizedBox(height: 32),

          // 4. Category Selector Section
          Text(
            'CATEGORY',
            style: AppTextStyles.labelSmall.copyWith(
                color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCategories.map((cat) {
              final sel = cat == category;
              final catColor = Color(kCategoryColors[cat] ?? 0xFF5C6BC0);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onCategoryChanged(cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: sel ? catColor.withValues(alpha: 0.12) : Colors.transparent,
                    border: Border.all(
                      color: sel ? catColor.withValues(alpha: 0.55) : muted.withValues(alpha: 0.28),
                      width: sel ? 1.5 : 0.75,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: catColor.withValues(alpha: sel ? 1.0 : 0.45),
                        ),
                      ),
                      const SizedBox(width: 7),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: sel ? catColor : muted,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        ),
                        child: Text(cat),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}