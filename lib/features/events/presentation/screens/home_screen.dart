import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../events/domain/event.dart';
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
  bool     _isEditing = false;
  EditTab  _editTab   = EditTab.active;

  EventFilter? _preEditFilter;

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

  void _switchTab(_HomeTab tab) {
    if (_activeTab == tab) return;
    HapticFeedback.selectionClick();
    if (_isEditing) _exitEditMode();
    setState(() => _activeTab = tab);
    _pageController.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Edit mode ───────────────────────────────────────────────────────────────

  void _toggleEdit() {
    HapticFeedback.selectionClick();
    _isEditing ? _exitEditMode() : _enterEditMode();
  }

  void _enterEditMode() {
    _preEditFilter = ref.read(eventFilterProvider);
    ref.read(eventFilterProvider.notifier).select(EventFilter.all);
    setState(() {
      _isEditing = true;
      _editTab   = EditTab.active;
    });
  }

  void _exitEditMode() {
    if (_preEditFilter != null) {
      ref.read(eventFilterProvider.notifier).select(_preEditFilter!);
      _preEditFilter = null;
    }
    setState(() {
      _isEditing = false;
      _editTab   = EditTab.active;
    });
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    switch (_activeTab) {
      case _HomeTab.events:
        context.push(AppRoutes.newEvent);
      case _HomeTab.counter:
        break;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq    = MediaQuery.of(context);

    final barClearance = max(mq.viewPadding.bottom, 40.0) + _stackHeight;
    final bottomPos    = max(mq.viewPadding.bottom, 40.0);

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
                    _Header(
                      isEditing:      _isEditing,
                      showEditButton: _activeTab == _HomeTab.events,
                      onEditTap:      _toggleEdit,
                      onSettingsTap:  () => HapticFeedback.selectionClick(),
                    ),
                    _TabRow(active: _activeTab, onSelect: _switchTab),
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
                      final newTab = _HomeTab.values[i];
                      if (_isEditing && newTab != _HomeTab.events) {
                        _exitEditMode();
                      }
                      setState(() => _activeTab = newTab);
                    },
                    children: [
                      EventsScreen(
                        key:       const ValueKey('events'),
                        isEditing: _isEditing,
                        editTab:   _editTab,
                      ),
                      _CounterTab(key: const ValueKey('counter')),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating bottom stack ─────────────────────────────────────────
          // In edit mode: show Active / Finished tab pills.
          // Otherwise: show the FAB + filter pills.
          Positioned(
            bottom: bottomPos,
            left: 0, right: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [

                // ── Normal bar — sizes the Stack ───────────────────────────────────
                IgnorePointer(
                  ignoring: _isEditing,
                  child: AnimatedOpacity(
                    opacity:  _isEditing ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve:    Curves.easeInOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 30),
                          child: FloatingActionButton(
                            onPressed:          _onFabPressed,
                            backgroundColor:    theme.colorScheme.onSurface,
                            foregroundColor:    theme.colorScheme.surface,
                            elevation:          2,
                            highlightElevation: 4,
                            shape:              const CircleBorder(),
                            tooltip:            'New',
                            child:              const Icon(Icons.add, size: 26),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                ),

                // ── Edit tab bar — pinned to bottom, never affects layout ──────────
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    ignoring: !(_isEditing && _activeTab == _HomeTab.events),
                    child: AnimatedOpacity(
                      opacity:  (_isEditing && _activeTab == _HomeTab.events) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve:    Curves.easeInOut,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: _EditTabBar(
                          selected: _editTab,
                          onSelect: (t) => setState(() => _editTab = t),
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

// ── _EditTabBar ───────────────────────────────────────────────────────────────
//
// Frosted-glass two-pill bar shown at the bottom while in edit mode.
// Matches the visual style of FilterPills.

class _EditTabBar extends StatelessWidget {
  const _EditTabBar({
    required this.selected,
    required this.onSelect,
  });

  final EditTab selected;
  final ValueChanged<EditTab> onSelect;

  static const double _kRadius = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28, offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: EditTab.values.map((tab) {
                return Expanded(
                  child: _EditTabPill(
                    label:    tab.label,
                    selected: selected == tab,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(tab);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _EditTabPill ──────────────────────────────────────────────────────────────

class _EditTabPill extends StatefulWidget {
  const _EditTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_EditTabPill> createState() => _EditTabPillState();
}

class _EditTabPillState extends State<_EditTabPill>
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
    final theme     = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap:       widget.onTap,
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity:  widget.selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve:    Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset:     const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve:    Curves.easeOut,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: widget.selected
                        ? onSurface
                        : onSurface.withValues(alpha: 0.45),
                    fontWeight: widget.selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  child: Text(widget.label, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.isEditing,
    required this.showEditButton,
    required this.onEditTap,
    required this.onSettingsTap,
  });

  final bool isEditing, showEditButton;
  final VoidCallback onEditTap, onSettingsTap;

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
                    isEditing
                        ? Icons.edit               // filled when active
                        : Icons.edit_outlined,     // outline at rest
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

// ── Logo placeholder ──────────────────────────────────────────────────────────

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onSurface.withValues(alpha: 0.08), width: 1),
      ),
      child: Icon(
        Icons.widgets_outlined, size: 17,
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
            .map((tab) => Expanded(
                  child: _TabItem(
                    label: tab.label,
                    selected: active == tab,
                    onTap: () => onSelect(tab),
                  ),
                ))
            .toList(),
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
    final theme     = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted     = theme.textTheme.bodyMedium?.color ??
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