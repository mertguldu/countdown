// home_screen.dart

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
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

  // Height of the floating bottom stack:
  //   FAB (56) + gap (20) + pills (~46) = ~122 px above the Positioned bottom edge.
  // The Positioned bottom itself is max(viewPadding.bottom, 40), so total
  // clearance from the screen bottom is that offset + 122.
  static const double _stackHeight = 122;

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

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    switch (_activeTab) {
      case _HomeTab.events:
        context.push(AppRoutes.newEvent);
      case _HomeTab.counter:
        // TODO: context.push(AppRoutes.newCounter)
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Single MediaQuery lookup — reused everywhere in this build call.
    final mq = MediaQuery.of(context);

    // Mirrors the Positioned(bottom: max(viewPadding.bottom, 40)) offset so the
    // scroll clearance is always accurate regardless of safe-area height.
    final barClearance = max(mq.viewPadding.bottom, 40.0) + _stackHeight;

    return Scaffold(
      body: Stack(
        children: [
          // ── Main column ────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo + Settings header ───────────────────────────
                    _Header(
                      onSettingsTap: () {
                        HapticFeedback.selectionClick();
                        // TODO: context.push(AppRoutes.settings)
                      },
                    ),

                    // ── Tab row ──────────────────────────────────────────
                    _TabRow(
                      active: _activeTab,
                      onSelect: _switchTab,
                    ),
                  ],
                ),
              ),

              // ── Page content ─────────────────────────────────────────────
              // Expand bottom padding via MediaQuery so scroll views inside
              // each tab automatically clear the floating bottom stack.
              Expanded(
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(
                      bottom: barClearance,
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
          Positioned(
            bottom: max(mq.viewPadding.bottom, 40.0),
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── FAB ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(right: 30),
                  child: FloatingActionButton(
                    onPressed: _onFabPressed,
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                    elevation: 2,
                    highlightElevation: 4,
                    shape: const CircleBorder(),
                    tooltip: 'New',
                    child: const Icon(Icons.add, size: 26),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Filter pills ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
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

// ── App header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _LogoPlaceholder(),
          const Spacer(),
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
        ],
      ),
    );
  }
}

// ── Logo placeholder ──────────────────────────────────────────────────────────

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.widgets_outlined,
        size: 17,
        color: onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

enum _HomeTab { events, counter }

extension _HomeTabX on _HomeTab {
  String get label => switch (this) {
        _HomeTab.events  => 'Events',
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
    final theme    = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted    = theme.textTheme.bodyMedium?.color ??
        onSurface.withValues(alpha: 0.45);

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