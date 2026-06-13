import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/event_repository.dart';
import '../../domain/event.dart';
import '../providers/events_provider.dart';
import 'new_event/new_event_constants.dart';
import 'new_event/new_event_shared_widgets.dart';
import 'new_event/steps/step_reminder.dart';

// ── Public API ────────────────────────────────────────────────────────────────

void showEventDetail(BuildContext context, int eventId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      snap: true,
      snapSizes: const [0.5, 0.88, 1.0],
      builder: (_, scrollCtrl) => EventDetailSheet(
        eventId: eventId,
        scrollController: scrollCtrl,
      ),
    ),
  );
}

// ── Main widget ───────────────────────────────────────────────────────────────

enum _EditingField { title, note }

class EventDetailSheet extends ConsumerStatefulWidget {
  const EventDetailSheet({
    super.key,
    required this.eventId,
    required this.scrollController,
  });

  final int eventId;
  final ScrollController scrollController;

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  _EditingField? _editing;

  final _titleCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();
  final _titleFocus = FocusNode();
  final _noteFocus  = FocusNode();

  bool _initialized = false;
  final _picker     = ImagePicker();

  // ── Reminder ──────────────────────────────────────────────────────────────
  Reminder _reminder    = Reminder.oneDay;
  int _customWeeks = 0, _customDays = 1, _customHours = 0, _customMins = 0;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() { if (!_titleFocus.hasFocus) _commitTitle(); });
    _noteFocus .addListener(() { if (!_noteFocus .hasFocus) _commitNote();  });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl .dispose();
    _titleFocus.dispose();
    _noteFocus .dispose();
    super.dispose();
  }

  void _initControllers(Event e) {
    if (_initialized) return;
    _titleCtrl.text = e.title;
    _noteCtrl .text = e.subtitle ?? '';
    _initialized    = true;

    // Restore reminder from DB. Fall back to sensible per-type defaults for
    // events that were created before this column existed (reminderType == null).
    final type = EventTypeX.fromDb(e.eventType);
    if (e.reminderType != null) {
      _reminder = Reminder.values.firstWhere(
        (r) => r.name == e.reminderType,
        orElse: () =>
            type == EventType.countup ? Reminder.custom : Reminder.oneDay,
      );
      // Decompose stored seconds back into the four stepper fields.
      final secs = e.reminderCustomSecs ?? 0;
      if (secs > 0) {
        final totalMins  = secs  ~/ 60;
        final totalHours = totalMins  ~/ 60;
        final totalDays  = totalHours ~/ 24;
        _customMins  = totalMins  % 60;
        _customHours = totalHours % 24;
        _customWeeks = totalDays  ~/ 7;
        _customDays  = totalDays  % 7;
      }
    } else {
      _reminder = type == EventType.countup ? Reminder.custom : Reminder.oneDay;
    }
  }

  // ── Commit ────────────────────────────────────────────────────────────────

  void _commitTitle() {
    final text = _titleCtrl.text.trim();
    if (text.isEmpty || !_initialized) return;
    _patch(EventsCompanion(title: Value(text)));
    if (mounted) setState(() => _editing = null);
  }

  void _commitNote() {
    if (!_initialized) return;
    final text = _noteCtrl.text.trim();
    _patch(EventsCompanion(subtitle: Value(text.isEmpty ? null : text)));
    if (mounted) setState(() => _editing = null);
  }

  void _patch(EventsCompanion companion) =>
      ref.read(eventRepositoryProvider).patchEvent(widget.eventId, companion);

  // ── Date / time ───────────────────────────────────────────────────────────

  Future<void> _pickDate(Event event) async {
    final isCountdown = EventTypeX.fromDb(event.eventType) == EventType.countdown;
    final current     = event.targetDate ?? DateTime.now();
    final picked      = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: isCountdown ? DateTime.now() : DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final newDate = DateTime(
        picked.year, picked.month, picked.day,
        current.hour, current.minute);
    _patch(EventsCompanion(targetDate: Value(newDate)));
    _rescheduleNotification(event, newTargetDate: newDate);
  }

  Future<void> _pickTime(Event event) async {
    final current = event.targetDate ?? DateTime.now();
    final picked  = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    final newDate = DateTime(
        current.year, current.month, current.day,
        picked.hour, picked.minute);
    _patch(EventsCompanion(targetDate: Value(newDate)));
    _rescheduleNotification(event, newTargetDate: newDate);
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  void _showCategoryPicker(Event event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Category',
        child: _CategoryList(
          selected: event.category,
          onSelect: (cat) {
            _patch(EventsCompanion(
              category:   Value(cat),
              colorValue: Value(kCategoryColors[cat] ?? 0xFF5C6BC0),
            ));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showRepeatPicker(Event event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Repeat',
        child: RepeatSheet(
          selected: RepeatOptionX.fromDb(event.repeatPeriod),
          onSelect: (opt) {
            _patch(EventsCompanion(
              repeatPeriod: opt != RepeatOption.never
                  ? Value(opt.name)
                  : const Value<String?>(null),
            ));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showResetPeriodPicker(Event event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Resets',
        child: _ResetPeriodList(
          selected: ResetPeriodX.fromDb(event.resetPeriod),
          onSelect: (period) {
            _patch(EventsCompanion(resetPeriod: Value(period.name)));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ── Reminder ──────────────────────────────────────────────────────────────

  void _showReminderPicker(Event event) {
    final isCountdown = EventTypeX.fromDb(event.eventType) == EventType.countdown;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderPickerSheet(
        isCountdown:  isCountdown,
        initial:      _reminder,
        initialWeeks: _customWeeks,
        initialDays:  _customDays,
        initialHours: _customHours,
        initialMins:  _customMins,
        onConfirm: (reminder, weeks, days, hours, mins) {
          setState(() {
            _reminder    = reminder;
            _customWeeks = weeks;
            _customDays  = days;
            _customHours = hours;
            _customMins  = mins;
          });
          // Persist so the UI survives sheet close / reopen.
          final customSecs = reminder == Reminder.custom
              ? Duration(
                  days:    weeks * 7 + days,
                  hours:   hours,
                  minutes: mins,
                ).inSeconds
              : null;
          _patch(EventsCompanion(
            reminderType:      Value(reminder.name),
            reminderCustomSecs: Value(customSecs),
          ));
          _rescheduleNotification(event);
        },
      ),
    );
  }

  Future<void> _rescheduleNotification(Event event, {DateTime? newTargetDate}) async {
    await NotificationService.cancel(event.id);
    final td = newTargetDate ?? event.targetDate;
    if (td == null) return;

    final type = EventTypeX.fromDb(event.eventType);
    DateTime? notifDate;
    String    body = '"${event.title}" is coming up.';

    if (type == EventType.countdown) {
      switch (_reminder) {
        case Reminder.oneWeek:
          notifDate = td.subtract(const Duration(days: 7));
          body = '"${event.title}" is 1 week away!';
        case Reminder.oneDay:
          notifDate = td.subtract(const Duration(days: 1));
          body = '"${event.title}" is tomorrow!';
        case Reminder.dayOf:
          notifDate = DateTime(td.year, td.month, td.day, 9);
          body = 'Today is "${event.title}"!';
        case Reminder.custom:
          final dur = _customDuration();
          if (dur.inMinutes > 0) {
            notifDate = td.subtract(dur);
            body = '"${event.title}" is coming up!';
          }
      }
    } else if (type == EventType.countup) {
      final dur = _customDuration();
      if (dur.inMinutes > 0) {
        notifDate = td.add(dur);
        body = '"${event.title}" milestone!';
      }
    }

    if (notifDate == null || notifDate.isBefore(DateTime.now())) return;
    await NotificationService.schedule(
      id:            event.id,
      title:         event.title,
      body:          body,
      scheduledDate: notifDate,
      payload:       event.id.toString(),
    );
  }

  Duration _customDuration() => Duration(
    days:    _customWeeks * 7 + _customDays,
    hours:   _customHours,
    minutes: _customMins,
  );

  String _reminderLabel(EventType type) {
    if (_reminder == Reminder.custom) {
      final parts = <String>[];
      if (_customWeeks > 0) parts.add('${_customWeeks}w');
      if (_customDays  > 0) parts.add('${_customDays}d');
      if (_customHours > 0) parts.add('${_customHours}h');
      if (_customMins  > 0) parts.add('${_customMins}m');
      if (parts.isEmpty) return 'None';
      final suffix = type == EventType.countup ? ' after' : ' before';
      return '${parts.join(' ')}$suffix';
    }
    return _reminder.label;
  }

  // ── Tally ─────────────────────────────────────────────────────────────────

  void _adjustTally(int delta) {
    HapticFeedback.selectionClick();
    ref.read(eventRepositoryProvider).adjustTallyCount(widget.eventId, delta);
  }

  Future<void> _resetTally(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset counter?'),
        content: Text('"${event.title}" will be reset to zero.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(eventRepositoryProvider).resetTally(widget.eventId);
    }
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (img == null || !mounted) return;
      final appDir    = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));
      await imagesDir.create(recursive: true);
      final dest = p.join(
          imagesDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(img.path).copy(dest);
      if (!mounted) return;
      _patch(EventsCompanion(photoPath: Value(dest)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open photo library.')),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${event.title}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await NotificationService.cancel(event.id);
    await ref.read(eventRepositoryProvider).deleteEvent(event.id);
    // Navigator.pop is intentionally omitted — deleting the row causes
    // watchById to emit null, triggering auto-close in build().
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return ref.watch(eventByIdProvider(widget.eventId)).when(
      data: (event) {
        if (event == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return const SizedBox.shrink();
        }
        _initControllers(event);
        return _buildSheet(context, event, surface);
      },
      loading: () => _shell(surface,
          child: const Center(child: CircularProgressIndicator.adaptive())),
      error: (e, _) => _shell(surface,
          child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _shell(Color surface, {required Widget child}) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: ColoredBox(color: surface, child: child),
  );

  Widget _buildSheet(BuildContext context, Event event, Color surface) {
    final type = EventTypeX.fromDb(event.eventType);
    final mq   = MediaQuery.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ColoredBox(
        color: surface,
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            // ── Hero ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _HeroSection(
                  event:       event,
                  onClose:     () => Navigator.pop(context),
                  onEditPhoto: _pickPhoto,
                  onAdjust:    type == EventType.tally ? _adjustTally : null,
                  onReset:     type == EventType.tally ? () => _resetTally(event) : null,
                ),
              ),
            ),

            // ── Fields ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildFields(context, event, type),
              ),
            ),

            // ── Delete (destructive row in its own group card) ────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _FieldGroup(children: [
                  _DestructiveRow(
                    label: 'Delete Event',
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _deleteEvent(event),
                  ),
                ]),
              ),
            ),

            SliverPadding(
                padding: EdgeInsets.only(
                    bottom: mq.viewPadding.bottom + 36)),
          ],
        ),
      ),
    );
  }

  Widget _buildFields(BuildContext context, Event event, EventType type) {
    Widget titleRow() => _editing == _EditingField.title
        ? _InlineEditRow(
            label: 'Title',
            icon:  Icons.title_rounded,
            ctrl:  _titleCtrl,
            focus: _titleFocus,
            onDone: () => _titleFocus.unfocus(),
          )
        : _FieldRow(
            label: 'Title',
            icon:  Icons.title_rounded,
            value: event.title,
            onTap: () {
              setState(() => _editing = _EditingField.title);
              Future.microtask(() => _titleFocus.requestFocus());
            },
          );

    Widget noteRow() => _editing == _EditingField.note
        ? _InlineEditRow(
            label: 'Note',
            icon:  Icons.notes_rounded,
            ctrl:  _noteCtrl,
            focus: _noteFocus,
            onDone: () => _noteFocus.unfocus(),
          )
        : _FieldRow(
            label: 'Note',
            icon:  Icons.notes_rounded,
            value: event.subtitle?.isNotEmpty == true
                ? event.subtitle!
                : 'Add a note…',
            valueIsHint: event.subtitle?.isNotEmpty != true,
            onTap: () {
              setState(() => _editing = _EditingField.note);
              Future.microtask(() => _noteFocus.requestFocus());
            },
          );

    return switch (type) {
      EventType.countdown => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Details group
            _FieldGroup(children: [titleRow(), noteRow()]),
            const SizedBox(height: 12),
            // Scheduling group
            _FieldGroup(children: [
              _FieldRow(
                label: 'Date',
                icon:  Icons.calendar_today_rounded,
                value: _fmtDate(event.targetDate),
                onTap: () => _pickDate(event),
              ),
              _FieldRow(
                label: 'Time',
                icon:  Icons.schedule_rounded,
                value: _fmtTime(event.targetDate),
                onTap: () => _pickTime(event),
              ),
              _FieldRow(
                label: 'Repeat',
                icon:  Icons.repeat_rounded,
                value: RepeatOptionX.fromDb(event.repeatPeriod).label,
                onTap: () => _showRepeatPicker(event),
              ),
              _FieldRow(
                label: 'Notification',
                icon:  Icons.notifications_outlined,
                value: _reminderLabel(EventType.countdown),
                onTap: () => _showReminderPicker(event),
              ),
            ]),
            const SizedBox(height: 12),
            // Meta group
            _FieldGroup(children: [
              _FieldRow(
                label: 'Category',
                icon:  Icons.label_outline_rounded,
                value: event.category,
                valueLeading: _ColorDot(Color(event.colorValue)),
                onTap: () => _showCategoryPicker(event),
              ),
            ]),
          ],
        ),
      ),
      EventType.countup => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldGroup(children: [titleRow(), noteRow()]),
            const SizedBox(height: 12),
            _FieldGroup(children: [
              _FieldRow(
                label: 'Started',
                icon:  Icons.calendar_today_rounded,
                value: '${_fmtDate(event.targetDate)}  ${_fmtTime(event.targetDate)}',
                onTap: () => _pickDate(event),
              ),
              _FieldRow(
                label: 'Notification',
                icon:  Icons.notifications_outlined,
                value: _reminderLabel(EventType.countup),
                onTap: () => _showReminderPicker(event),
              ),
            ]),
            const SizedBox(height: 12),
            _FieldGroup(children: [
              _FieldRow(
                label: 'Category',
                icon:  Icons.label_outline_rounded,
                value: event.category,
                valueLeading: _ColorDot(Color(event.colorValue)),
                onTap: () => _showCategoryPicker(event),
              ),
            ]),
          ],
        ),
      ),
      EventType.tally => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldGroup(children: [titleRow(), noteRow()]),
            const SizedBox(height: 12),
            _FieldGroup(children: [
              _FieldRow(
                label: 'Resets',
                icon:  Icons.refresh_rounded,
                value: ResetPeriodX.fromDb(event.resetPeriod).pickerLabel,
                onTap: () => _showResetPeriodPicker(event),
              ),
              _FieldRow(
                label: 'Category',
                icon:  Icons.label_outline_rounded,
                value: event.category,
                valueLeading: _ColorDot(Color(event.colorValue)),
                onTap: () => _showCategoryPicker(event),
              ),
            ]),
            // Last-reset caption
            if (event.lastResetAt != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Last reset ${_fmtDate(event.lastResetAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.38),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime? dt) =>
      dt == null ? '—' : DateFormat('EEE d MMM yyyy').format(dt);

  String _fmtTime(DateTime? dt) =>
      dt == null ? '—' : DateFormat('h:mm a').format(dt);
}

// ── Drag handle ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: onSurf.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ── Field group card ──────────────────────────────────────────────────────────

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
      decoration: BoxDecoration(
        color: onSurf.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0,
                thickness: 0.5,
                indent: 46,
                color: onSurf.withValues(alpha: 0.08),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  const _HeroSection({
    required this.event,
    required this.onClose,
    required this.onEditPhoto,
    this.onAdjust,
    this.onReset,
  });

  final Event                   event;
  final VoidCallback            onClose;
  final VoidCallback            onEditPhoto;
  final void Function(int)?     onAdjust;
  final VoidCallback?           onReset;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  Timer?   _timer;
  Duration _diff = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_HeroSection old) {
    super.didUpdateWidget(old);
    if (old.event.targetDate != widget.event.targetDate) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _diff  = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _diff = _compute());
    });
  }

  Duration _compute() {
    final td   = widget.event.targetDate;
    if (td == null) return Duration.zero;
    final type = EventTypeX.fromDb(widget.event.eventType);
    return type == EventType.countup
        ? DateTime.now().difference(td)
        : td.difference(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final type  = EventTypeX.fromDb(event.eventType);
    final color = Color(event.colorValue);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background ─────────────────────────────────────────────
            _background(event, color),

            // ── Gradient vignette ───────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.black.withValues(
                        alpha: type == EventType.tally ? 0.40 : 0.72),
                  ],
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            if (type == EventType.tally)
              _tallyContent(event)
            else
              _timerContent(event, type),

            // ── Top controls (close left, photo right) ──────────────────
            Positioned(
              top: 12, left: 12, right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                      icon: Icons.close_rounded,
                      onTap: widget.onClose),
                  _CircleIconButton(
                    icon: widget.event.photoPath != null
                        ? Icons.edit_outlined
                        : Icons.add_a_photo_outlined,
                    onTap: widget.onEditPhoto,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _background(Event event, Color color) {
    if (event.photoPath != null) {
      return Image.file(
        File(event.photoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _colorBg(color),
      );
    }
    return _colorBg(color);
  }

  Widget _colorBg(Color c) {
    final dark = HSLColor.fromColor(c)
        .withLightness(
            (HSLColor.fromColor(c).lightness - 0.18).clamp(0.0, 1.0))
        .toColor();
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.7),
          radius: 1.6,
          colors: [
            c.withValues(alpha: 0.95),
            c.withValues(alpha: 0.7),
            dark.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _timerContent(Event event, EventType type) {
    final isCountdown = type == EventType.countdown;
    final diff        = _diff;
    final finished    = isCountdown && (diff.isNegative || diff == Duration.zero);
    final pending     = !isCountdown && diff.isNegative;

    final days    = diff.inDays.abs();
    final h       = diff.inHours.remainder(24).abs();
    final m       = diff.inMinutes.remainder(60).abs();
    final s       = diff.inSeconds.remainder(60).abs();
    final timeStr = h > 0 ? '$h:${_z(m)}:${_z(s)}'
                  : m > 0 ? '$m:${_z(s)}'
                  : '$s';

    return Positioned(
      bottom: 24, left: 20, right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.title,
            style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 0.1),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (finished)
            _StatusBadge(label: 'Finished ✓')
          else if (pending)
            _StatusBadge(
              label: diff.inDays.abs() > 0
                  ? 'Starts in ${diff.inDays.abs()} days'
                  : 'Starting soon',
            )
          else ...[
            if (days > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$days',
                    style: AppTextStyles.frauncesMedium.copyWith(
                        fontSize: 64,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        height: 1.0),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      days == 1 ? 'DAY' : 'DAYS',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.60),
                          letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            Text(
              timeStr,
              style: (days == 0
                      ? AppTextStyles.frauncesMedium.copyWith(fontSize: 64)
                      : AppTextStyles.bodyMedium)
                  .copyWith(
                    color: days == 0
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.60),
                    fontStyle: FontStyle.italic,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tallyContent(Event event) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.85)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeroCountBtn(
                  icon: Icons.remove_rounded,
                  enabled: event.tallyCount > 0,
                  onTap: () => widget.onAdjust?.call(-1),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    '${event.tallyCount}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.frauncesMedium.copyWith(
                        fontSize: 64,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        height: 1.0),
                  ),
                ),
                _HeroCountBtn(
                  icon: Icons.add_rounded,
                  enabled: true,
                  onTap: () => widget.onAdjust?.call(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ResetPeriodX.fromDb(event.resetPeriod).displayLabel,
            style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.52)),
          ),
        ],
      ),
    ),
  );

  String _z(int n) => n.toString().padLeft(2, '0');
}

// ── Status badge (finished / pending) ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontStyle: FontStyle.italic),
    ),
  );
}

// ── Field row ─────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueLeading,
    this.valueIsHint = false,
    this.icon,
  });

  final String        label;
  final String        value;
  final VoidCallback? onTap;
  final Widget?       valueLeading;
  final bool          valueIsHint;
  final IconData?     icon;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final muted  = Theme.of(context).textTheme.bodyMedium?.color
        ?? onSurf.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: muted.withValues(alpha: 0.55)),
              const SizedBox(width: 12),
            ],
            Text(label,
                style: AppTextStyles.bodyMedium.copyWith(color: muted)),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (valueLeading != null) ...[
                    valueLeading!,
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: valueIsHint
                            ? muted.withValues(alpha: 0.40)
                            : onSurf,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 16,
                        color: muted.withValues(alpha: 0.35)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline edit row ───────────────────────────────────────────────────────────

class _InlineEditRow extends StatelessWidget {
  const _InlineEditRow({
    super.key,
    required this.label,
    required this.ctrl,
    required this.focus,
    required this.onDone,
    this.icon,
  });

  final String                label;
  final TextEditingController ctrl;
  final FocusNode             focus;
  final VoidCallback          onDone;
  final IconData?             icon;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final muted  = Theme.of(context).textTheme.bodyMedium?.color
        ?? onSurf.withValues(alpha: 0.45);
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
          ],
          Text(label,
              style: AppTextStyles.bodyMedium.copyWith(color: muted)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(color: onSurf),
              decoration: InputDecoration(
                hintText: 'Enter $label…',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: muted.withValues(alpha: 0.40)),
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onDone(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Done',
                  style: AppTextStyles.labelLarge.copyWith(color: accent)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Destructive row ───────────────────────────────────────────────────────────

class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: error.withValues(alpha: 0.85)),
            const SizedBox(width: 12),
            Text(label,
                style: AppTextStyles.bodyMedium.copyWith(color: error)),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.30)),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 11, height: 11,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _HeroCountBtn extends StatelessWidget {
  const _HeroCountBtn(
      {required this.icon, required this.enabled, required this.onTap});
  final IconData     icon;
  final bool         enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: enabled ? 0.22 : 0.06),
      ),
      child: Icon(icon,
          color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.25),
          size: 24),
    ),
  );
}

// ── Picker sheet wrapper ──────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Material(
        color: surface,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: onSurf.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(title,
                    style:
                        AppTextStyles.titleMedium.copyWith(color: onSurf)),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category list ─────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.selected, required this.onSelect});
  final String               selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kCategories.map((cat) {
          final color = Color(kCategoryColors[cat] ?? 0xFF5C6BC0);
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24),
            leading: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color)),
            title: Text(cat,
                style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
            trailing: cat == selected
                ? Icon(Icons.check_rounded, color: onSurf, size: 20)
                : null,
            onTap: () => onSelect(cat),
          );
        }).toList(),
      ),
    );
  }
}

// ── Reset period list ─────────────────────────────────────────────────────────

class _ResetPeriodList extends StatelessWidget {
  const _ResetPeriodList({required this.selected, required this.onSelect});
  final ResetPeriod               selected;
  final ValueChanged<ResetPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ResetPeriod.values.map((period) {
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24),
            title: Text(period.pickerLabel,
                style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
            trailing: period == selected
                ? Icon(Icons.check_rounded, color: onSurf, size: 20)
                : null,
            onTap: () => onSelect(period),
          );
        }).toList(),
      ),
    );
  }
}

// ── Reminder picker sheet ─────────────────────────────────────────────────────

class _ReminderPickerSheet extends StatefulWidget {
  const _ReminderPickerSheet({
    required this.isCountdown,
    required this.initial,
    required this.initialWeeks,
    required this.initialDays,
    required this.initialHours,
    required this.initialMins,
    required this.onConfirm,
  });

  final bool     isCountdown;
  final Reminder initial;
  final int      initialWeeks, initialDays, initialHours, initialMins;
  final void Function(Reminder, int, int, int, int) onConfirm;

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late Reminder _selected;
  late int _weeks, _days, _hours, _mins;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _weeks    = widget.initialWeeks;
    _days     = widget.initialDays;
    _hours    = widget.initialHours;
    _mins     = widget.initialMins;
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final options = widget.isCountdown ? Reminder.values : [Reminder.custom];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: surface,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: onSurf.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Sheet title
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Notification',
                  style: AppTextStyles.titleMedium.copyWith(color: onSurf),
                ),
              ),
              // Options list
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options.map((opt) {
                      final isSel = opt == _selected;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selected = opt);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: onSurf.withValues(alpha: 0.10),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSel
                                            ? onSurf
                                            : onSurf.withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSel
                                        ? Center(
                                            child: Container(
                                              width: 10, height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: onSurf,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    opt.label,
                                    style: AppTextStyles.bodyLarge
                                        .copyWith(color: onSurf),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Custom duration inputs expand inline when selected
                          if (opt == Reminder.custom && isSel)
                            CustomReminderBoxes(
                              isCountingDown: widget.isCountdown,
                              weeks:          _weeks,
                              days:           _days,
                              hours:          _hours,
                              mins:           _mins,
                              onWeeksChanged: (v) =>
                                  setState(() => _weeks = v),
                              onDaysChanged:  (v) =>
                                  setState(() => _days  = v),
                              onHoursChanged: (v) =>
                                  setState(() => _hours = v),
                              onMinsChanged:  (v) =>
                                  setState(() => _mins  = v),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      widget.onConfirm(
                          _selected, _weeks, _days, _hours, _mins);
                      Navigator.pop(context);
                    },
                    child: const Text('Set reminder'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}