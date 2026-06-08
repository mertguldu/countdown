import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../events/presentation/screens/events_screen.dart';

// ── HomeScreen ────────────────────────────────────────────────────────────────
//
// Shell that owns:
//   • The "moments" Fraunces header + widget-config shortcut icon
//   • Events | Counter tab switcher
//   • The FAB (add new event)
//
// The active tab body (EventsScreen or _CounterTab) is swapped in the Expanded
// area below the tab row.

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeTab _activeTab = _HomeTab.events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // "moments" wordmark in Fraunces italic
                  Text(
                    'moments',
                    style: AppTextStyles.frauncesLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  // Widget-config shortcut — □ icon matches design glyph
                  IconButton(
                    icon: const Icon(Icons.crop_square_rounded, size: 26),
                    color: theme.colorScheme.onSurface,
                    tooltip: 'Widget settings',
                    onPressed: () {
                      // TODO: context.push(AppRoutes.widgetConfig)
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab row ───────────────────────────────────────────────────────
            _TabRow(
              active: _activeTab,
              onSelect: (tab) => setState(() => _activeTab = tab),
            ),

            // Thin full-width divider matching the design
            Divider(
              height: 1,
              thickness: 0.5,
              color:
                  theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),

            // ── Tab body ──────────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (_activeTab) {
                  _HomeTab.events => const EventsScreen(key: ValueKey('events')),
                  _HomeTab.counter => const _CounterTab(key: ValueKey('counter')),
                },
              ),
            ),
          ],
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: context.push(AppRoutes.newEvent)
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Add event',
        child: const Icon(Icons.crop_square_rounded, size: 24),
      ),
    );
  }
}

// ── Tab row ───────────────────────────────────────────────────────────────────

enum _HomeTab { events, counter }

class _TabRow extends StatelessWidget {
  const _TabRow({required this.active, required this.onSelect});

  final _HomeTab active;
  final ValueChanged<_HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _TabItem(
            label: 'Events',
            selected: active == _HomeTab.events,
            onTap: () => onSelect(_HomeTab.events),
          ),
          const SizedBox(width: 28),
          _TabItem(
            label: 'Counter',
            selected: active == _HomeTab.counter,
            onTap: () => onSelect(_HomeTab.counter),
          ),
        ],
      ),
    );
  }
}

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
        theme.textTheme.bodyMedium?.color ?? onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.titleMedium.copyWith(
                color: selected ? onSurface : muted,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 8),
            // White underline indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 2,
              width: selected ? 20 : 0,
              decoration: BoxDecoration(
                color: onSurface,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Counter tab stub ──────────────────────────────────────────────────────────
// Replace once the counter feature is designed and built.

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