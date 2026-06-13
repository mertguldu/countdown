import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.isEditing,
    required this.showEditButton,
    required this.onEditTap,
    required this.onSettingsTap,
  });

  final bool isEditing;
  final bool showEditButton;
  final VoidCallback onEditTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const LogoPlaceholder(),
          const Spacer(),

          // ── Settings ─────────────────────────────────────────────────────
          IconButton(
            onPressed: onSettingsTap,
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: onSurface.withValues(alpha: 0.45),
            ),
          ),

          // ── Edit (pencil) ─────────────────────────────────────────────────
          if (showEditButton) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEditTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Icon(
                    isEditing ? Icons.edit : Icons.edit_outlined,
                    key: ValueKey(isEditing),
                    size: 20,
                    color: isEditing
                        ? onSurface
                        : onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LogoPlaceholder extends StatelessWidget {
  const LogoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onSurface.withValues(alpha: 0.08), width: 1),
      ),
      child: Icon(
        Icons.widgets_outlined,
        size: 17,
        color: onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}