// home_screen.dart

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../events/presentation/screens/events_screen.dart';
import '../widgets/filter_pills.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeTab _activeTab = _HomeTab.events;
  late final PageController _pageController;

  // Total height of the floating stack:
  //   settings (56) + gap (14) + FAB (56) + gap (12) + pills (~46) + 16 bottom gap
  //   Uses viewPadding (stable, unaffected by keyboard) for the safe area inset.
  double get _barClearance =>
      MediaQuery.of(context).viewPadding.bottom + 200;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(_HomeTab tab) {
    if (_activeTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _activeTab = tab);
    _pageController.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // ── Main column ────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: _TabRow(
                  active: _activeTab,
                  onSelect: _switchTab,
                ),
              ),

              // ── Page content ─────────────────────────────────────────────
              // Expand bottom padding via MediaQuery so scroll views inside
              // each tab automatically clear the floating bottom stack.
              Expanded(
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(
                      bottom: _barClearance,
                    ),
                  ),
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _activeTab = _HomeTab.values[i]);
                    },
                    children: [
                      EventsScreen(key: const ValueKey('events')),
                      _CounterTab(key: const ValueKey('counter')),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating bottom stack ──────────────────────────────────────
          //
          // max(bottomInset, 24) means:
          //   iOS     → max(34, 34) = 34 — safe area wins, bar clears home indicator
          //   Android → max( 0, 34) = 34 — fixed gap wins, bar sits 34 px up
          // No SafeArea wrapper, no platform branching needed.
          Positioned(
            bottom: max(mq.viewPadding.bottom, 34),
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Settings (frosted glass circle) ──────────────────────
                _GlassCircleButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    // TODO: context.push(AppRoutes.settings)
                  },
                ),

                const SizedBox(height: 14),

                // ── FAB (solid, primary action) ───────────────────────────
                FloatingActionButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    // TODO: route based on _activeTab
                    //   events  → context.push(AppRoutes.newEvent)
                    //   counter → context.push(AppRoutes.newCounter)
                  },
                  backgroundColor: theme.colorScheme.onSurface,
                  foregroundColor: theme.colorScheme.surface,
                  elevation: 2,
                  highlightElevation: 4,
                  shape: const CircleBorder(),
                  tooltip: 'New',
                  child: const Icon(Icons.add, size: 26),
                ),

                const SizedBox(height: 12),

                // ── Filter pills (narrower, taller) ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FilterPills(
                    selected: ref.watch(eventFilterProvider),
                    onSelect: ref.read(eventFilterProvider.notifier).select,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass circle button ───────────────────────────────────────────────────────
//
// Frosted-glass circle that matches the FilterPills visual language —
// same blur, same translucent fill, same hairline border.

class _GlassCircleButton extends StatefulWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip = '',
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) => _ctrl.reverse(),
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface.withValues(alpha: 0.88),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

enum _HomeTab { events, counter }

extension _HomeTabX on _HomeTab {
  String get label => switch (this) {
        _HomeTab.events => 'Events',
        _HomeTab.counter => 'Counter',
      };
}

// ── Tab row ───────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  const _TabRow({required this.active, required this.onSelect});

  final _HomeTab active;
  final ValueChanged<_HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: _HomeTab.values
            .map(
              (tab) => Expanded(
                child: _TabItem(
                  label: tab.label,
                  selected: active == tab,
                  onTap: () => onSelect(tab),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Tab item ──────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted =
        theme.textTheme.bodyMedium?.color ?? onSurface.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.titleMedium.copyWith(
                color: selected ? onSurface : muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 2,
            color: selected ? onSurface : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

// ── Counter tab stub ──────────────────────────────────────────────────────────

class _CounterTab extends StatelessWidget {
  const _CounterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Center(
      child: Text(
        'Counter — coming soon',
        style: AppTextStyles.bodyMedium.copyWith(color: muted),
      ),
    );
  }
}