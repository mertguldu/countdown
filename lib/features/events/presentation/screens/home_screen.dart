import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../events/domain/event.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../events/presentation/screens/events_screen.dart';
import '../../../events/presentation/screens/tally_screen.dart';
import '../widgets/filter_pills.dart';

// Local Widget Imports
import '../widgets/home_header.dart';
import '../widgets/home_tabs.dart';
import '../widgets/home_edit_bars.dart';
import '../widgets/pill_layer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeTab _activeTab = HomeTab.events;
  bool _isEditing = false;
  EditTab _editTab = EditTab.active;

  late final PageController _pageController;

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

  // ── Tab switching ───────────────────────────────────────────────────────────

  void _switchTab(HomeTab tab) {
    if (_activeTab == tab) return;
    HapticFeedback.selectionClick();
    if (_isEditing) _exitEditMode();
    setState(() => _activeTab = tab);
    _pageController.jumpToPage(tab.index);
  }

  // ── Edit mode ───────────────────────────────────────────────────────────────

  void _toggleEdit() {
    HapticFeedback.selectionClick();
    _isEditing ? _exitEditMode() : _enterEditMode();
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
      _editTab = EditTab.active;
    });
    // Snap tally to Category view — dragging without group anchors is confusing.
    if (_activeTab == HomeTab.tally) {
      ref.read(tallyViewModeProvider.notifier).select(TallyViewMode.category);
    }
  }

  void _exitEditMode() {
    setState(() {
      _isEditing = false;
      _editTab = EditTab.active;
    });
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    final preselect = switch (_activeTab) {
      HomeTab.events => EventType.countdown,
      HomeTab.countUp => EventType.countup,
      HomeTab.tally => EventType.tally,
    };
    context.push(AppRoutes.newEvent, extra: preselect);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    final barClearance = max(mq.viewPadding.bottom, 40.0) + _stackHeight;
    final bottomPos = max(mq.viewPadding.bottom, 40.0);

    return Scaffold(
      body: Stack(
        children: [
          // ── Main column ───────────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HomeHeader(
                      isEditing: _isEditing,
                      showEditButton: true,
                      onEditTap: _toggleEdit,
                      onSettingsTap: () => HapticFeedback.selectionClick(),
                    ),
                    HomeTabRow(active: _activeTab, onSelect: _switchTab),
                  ],
                ),
              ),
              Expanded(
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(bottom: barClearance),
                  ),
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      final newTab = HomeTab.values[i];
                      if (_isEditing && newTab != HomeTab.events) {
                        _exitEditMode();
                      }
                      setState(() => _activeTab = newTab);
                    },
                    children: [
                      // Tab 1 — Countdown events
                      EventsScreen(
                        key: const ValueKey('events'),
                        isEditing: _isEditing && _activeTab == HomeTab.events,
                        editTab: _editTab,
                        eventTypeFilter: EventType.countdown,
                      ),
                      // Tab 2 — Count-up events
                      EventsScreen(
                        key: const ValueKey('countup'),
                        isEditing: _isEditing && _activeTab == HomeTab.countUp,
                        editTab: EditTab.active,
                        eventTypeFilter: EventType.countup,
                      ),
                      // Tab 3 — Tally counters
                      TallyScreen(
                        key: const ValueKey('tally'),
                        isEditing: _isEditing && _activeTab == HomeTab.tally,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating bottom stack ─────────────────────────────────────────
          Positioned(
            bottom: bottomPos,
            left: 0,
            right: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Normal bar (FAB + pills) ──────────────────────────────────
                IgnorePointer(
                  ignoring: _isEditing,
                  child: AnimatedOpacity(
                    opacity: _isEditing ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

                        // Pill area
                        Stack(
                          children: [
                            PillLayer(
                              visible: _activeTab == HomeTab.events,
                              child: FilterPills(
                                selected: ref.watch(eventFilterProvider),
                                onSelect: ref
                                    .read(eventFilterProvider.notifier)
                                    .select,
                              ),
                            ),
                            PillLayer(
                              visible: _activeTab == HomeTab.countUp,
                              child: CountUpFilterPills(
                                selected: ref.watch(countUpFilterProvider),
                                onSelect: ref
                                    .read(countUpFilterProvider.notifier)
                                    .select,
                              ),
                            ),
                            PillLayer(
                              visible: _activeTab == HomeTab.tally,
                              child: TallyViewPills(
                                selected: ref.watch(tallyViewModeProvider),
                                onSelect: ref
                                    .read(tallyViewModeProvider.notifier)
                                    .select,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Edit bar: Events (Active / Finished) ──────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !(_isEditing && _activeTab == HomeTab.events),
                    child: AnimatedOpacity(
                      opacity: (_isEditing && _activeTab == HomeTab.events)
                          ? 1.0
                          : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: EditTabBar(
                          selected: _editTab,
                          onSelect: (t) => setState(() => _editTab = t),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Edit bar: Tally (Category / All) ──────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !(_isEditing && _activeTab == HomeTab.tally),
                    child: AnimatedOpacity(
                      opacity: (_isEditing && _activeTab == HomeTab.tally)
                          ? 1.0
                          : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: TallyEditBar(
                          selected: ref.watch(tallyViewModeProvider),
                          onSelect: ref
                              .read(tallyViewModeProvider.notifier)
                              .select,
                        ),
                      ),
                    ),
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