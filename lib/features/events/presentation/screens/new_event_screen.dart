import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/event_repository.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kCategories = [
  'Trips', 'Birthdays', 'Anniversaries', 'Personal',
  'Holidays', 'Work', 'Family', 'Health',
  'Milestones', 'Sports', 'School', 'Concerts',
  'Weddings', 'Other',
];

const _kCategoryColors = <String, int>{
  'Trips':         0xFF5C6BC0,
  'Birthdays':     0xFFEF5350,
  'Anniversaries': 0xFF26A69A,
  'Personal':      0xFFFF7043,
  'Holidays':      0xFFAB47BC,
  'Work':          0xFF42A5F5,
  'Family':        0xFFEC407A,
  'Health':        0xFF66BB6A,
  'Milestones':    0xFFFFCA28,
  'Sports':        0xFF26C6DA,
  'School':        0xFF8D6E63,
  'Concerts':      0xFFFF8A65,
  'Weddings':      0xFFBA68C8,
  'Other':         0xFF78909C,
};

const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _Reminder {
  oneWeek('1 week before'),
  oneDay('1 day before'),
  dayOf('Day of'),
  custom('Custom…');

  const _Reminder(this.label);
  final String label;
}

enum _RepeatOption {
  never('Never'),
  daily('Daily'),
  weekly('Weekly'),
  biweekly('Every 2 weeks'),
  monthly('Monthly'),
  yearly('Yearly');

  const _RepeatOption(this.label);
  final String label;
}

// ── NewEventScreen ────────────────────────────────────────────────────────────

class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({super.key});

  @override
  ConsumerState<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends ConsumerState<NewEventScreen> {
  int _step = 1;
  static const int _kTotal = 4;
  bool _done = false;
  bool _saving = false;
  String _createdName = '';

  // ── Step 1 ───────────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  String _category = 'Trips';
  bool _nameError = false;

  // ── Step 2 ───────────────────────────────────────────────────────────────────
  bool _isCountingDown = true;
  late int _calYear;
  late int _calMonth; // 1-indexed
  late int _calDay;
  int _calHour = 0;
  int _calMinute = 0;

  // ── Step 3 ───────────────────────────────────────────────────────────────────
  final _noteCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  _RepeatOption _repeatOption = _RepeatOption.never;
  String? _imagePath;
  final _picker = ImagePicker();

  // ── Step 4 ───────────────────────────────────────────────────────────────────
  _Reminder _reminder      = _Reminder.oneDay;
  int _customWeeks  = 0;
  int _customDays   = 1;
  int _customHours  = 0;
  int _customMins   = 0;

  // ── Life-cycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear  = now.year;
    _calMonth = now.month;
    _calDay   = now.day;
    // Default to the next hour so the time is immediately valid for countdown.
    final defaultTime = now.add(const Duration(hours: 1));
    _calHour   = defaultTime.hour;
    _calMinute = 0;
    _nameCtrl.addListener(_onNameTyped);
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onNameTyped)
      ..dispose();
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _onNameTyped() {
    if (_nameError && _nameCtrl.text.trim().isNotEmpty) {
      setState(() => _nameError = false);
    }
  }

  DateTime get _selectedDate =>
      DateTime(_calYear, _calMonth, _calDay, _calHour, _calMinute);

  int get _colorValue => _kCategoryColors[_category] ?? 0xFF5C6BC0;

  String _fmt12h(int hour, int minute) {
    final h    = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $ampm';
  }

  // ── Step 2 actions ────────────────────────────────────────────────────────────

  void _onTypeChanged(bool isDown) {
    setState(() {
      _isCountingDown = isDown;
      if (!isDown) {
        // Counting-up events don't use before-reminders
        _reminder = _Reminder.custom;
      } else {
        _reminder = _Reminder.oneDay;
        // If the current selection is in the past, reset to today + next hour.
        final now = DateTime.now();
        if (_selectedDate.isBefore(now)) {
          final next = now.add(const Duration(hours: 1));
          _calYear   = now.year;
          _calMonth  = now.month;
          _calDay    = now.day;
          _calHour   = next.hour;
          _calMinute = 0;
        }
      }
    });
  }

  void _prevMonth() => setState(() {
        _calMonth--;
        if (_calMonth < 1) { _calMonth = 12; _calYear--; }
        _clampDay();
      });

  void _nextMonth() => setState(() {
        _calMonth++;
        if (_calMonth > 12) { _calMonth = 1; _calYear++; }
        _clampDay();
      });

  void _clampDay() {
    final daysInMonth = DateTime(_calYear, _calMonth + 1, 0).day;
    if (_calDay > daysInMonth) _calDay = daysInMonth;
    // If counting down and the clamped date is now in the past, jump to 1st.
    if (_isCountingDown) {
      final now = DateTime.now();
      final clamped = DateTime(_calYear, _calMonth, _calDay);
      if (clamped.isBefore(DateTime(now.year, now.month, now.day))) {
        _calDay = now.day.clamp(1, daysInMonth);
      }
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _calHour, minute: _calMinute),
    );
    if (t == null || !mounted) return;

    // For countdown: if today is selected, the chosen time must be in the future.
    if (_isCountingDown) {
      final now = DateTime.now();
      final isToday = _calYear == now.year &&
          _calMonth == now.month &&
          _calDay   == now.day;
      if (isToday) {
        final picked = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        if (!picked.isAfter(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pick a time later than right now.'),
              duration: Duration(seconds: 2),
            ),
          );
          return; // leave the existing time unchanged
        }
      }
    }

    setState(() { _calHour = t.hour; _calMinute = t.minute; });
  }

  // ── Step 3 actions ────────────────────────────────────────────────────────────

  void _showRepeatPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _RepeatSheet(
        selected: _repeatOption,
        onSelect: (opt) {
          setState(() => _repeatOption = opt);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickImage() async {
    // iOS: NSPhotoLibraryUsageDescription must be in ios/Runner/Info.plist
    // Android 13+: no extra manifest entry needed (image_picker ≥ 0.8.6)
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (img == null || !mounted) return;

      // Copy to app documents so the path stays valid after the picker closes.
      final appDir    = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));
      await imagesDir.create(recursive: true);
      final dest = p.join(
          imagesDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(img.path).copy(dest);

      if (mounted) setState(() => _imagePath = dest);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open photo library. Check app permissions in Settings.'),
          ),
        );
      }
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  void _next() {
    if (_step == 1 && _nameCtrl.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _nameError = true);
      return;
    }
    // Step 2: for countdown, the chosen datetime must be in the future.
    if (_step == 2 && _isCountingDown && !_selectedDate.isAfter(DateTime.now())) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a date and time in the future.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_step == _kTotal) {
      _createEvent();
    } else {
      HapticFeedback.selectionClick();
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 1) {
      HapticFeedback.selectionClick();
      setState(() => _step--);
    }
  }

  // ── Event creation ────────────────────────────────────────────────────────────

  Future<void> _createEvent() async {
    setState(() => _saving = true);

    // 1. Safely ask for permission (catch any platform errors so it doesn't block)
    try {
      await NotificationService.requestPermissions();
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }

    final name     = _nameCtrl.text.trim().isEmpty ? 'My moment' : _nameCtrl.text.trim();
    final noteText = _noteCtrl.text.trim();

    try {
      // 2. Insert into the database
      final repo    = ref.read(eventRepositoryProvider);
      final eventId = await repo.insertEvent(
        EventsCompanion(
          title:      Value(name),
          subtitle:   noteText.isNotEmpty ? Value(noteText) : const Value.absent(),
          category:   Value(_category),
          targetDate: Value(_selectedDate),
          colorValue: Value(_colorValue),
          photoPath:  _imagePath != null ? Value(_imagePath!) : const Value.absent(),
        ),
      );

      // 3. Safely schedule the notification
      try {
        await _scheduleNotification(eventId, name);
      } catch (notificationError) {
        // The event was saved, but the alarm permission was likely denied.
        debugPrint('Failed to schedule notification: $notificationError');
        
        // Optional: Let the user know the notification failed but the event is safe.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event saved, but notifications are disabled.')),
          );
        }
      }

      // 4. Always proceed to the success screen if the DB insert worked
      if (mounted) {
        setState(() { _saving = false; _done = true; _createdName = name; });
      }
    } catch (e) {
      // This catch block now ONLY handles database insertion failures
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save event: $e')));
      }
    }
  }

  Future<void> _scheduleNotification(int eventId, String name) async {
    DateTime? notifDate;
    String    body = '"$name" is coming up soon.';

    if (_isCountingDown) {
      switch (_reminder) {
        case _Reminder.oneWeek:
          notifDate = _selectedDate.subtract(const Duration(days: 7));
          body = '"$name" is 1 week away!';
        case _Reminder.oneDay:
          notifDate = _selectedDate.subtract(const Duration(days: 1));
          body = '"$name" is tomorrow!';
        case _Reminder.dayOf:
          notifDate = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day, 9);
          body = 'Today is "$name"!';
        case _Reminder.custom:
          final dur = _customDuration();
          if (dur.inMinutes > 0) {
            notifDate = _selectedDate.subtract(dur);
            body = '"$name" is coming up!';
          }
      }
    } else {
      // Counting up — fire X time after the start date
      final dur = _customDuration();
      if (dur.inMinutes > 0) {
        notifDate = _selectedDate.add(dur);
        body = '"$name" milestone!';
      }
    }

    if (notifDate == null || notifDate.isBefore(DateTime.now())) return;

    await NotificationService.schedule(
      id: eventId, title: name, body: body,
      scheduledDate: notifDate, payload: eventId.toString(),
    );
  }

  Duration _customDuration() => Duration(
        days:    _customWeeks * 7 + _customDays,
        hours:   _customHours,
        minutes: _customMins,
      );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!_done)
              _NavBar(
                step: _step, totalSteps: _kTotal,
                onBack: _step > 1 ? _prev : null,
                onClose: () => context.pop(),
              ),

            Expanded(
              child: _done
                  ? _DoneView(name: _createdName, onDone: () => context.pop())
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: KeyedSubtree(
                          key: ValueKey(_step), child: _buildStep()),
                    ),
            ),

            if (!_done) ...[
              _CtaArea(
                isLastStep:  _step == _kTotal,
                isSkippable: _step == 3,
                saving:      _saving,
                onCta:       _next,
                onSkip:      _next,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        1 => _StepName(
              nameCtrl:          _nameCtrl,
              category:          _category,
              onCategoryChanged: (c) => setState(() => _category = c),
              hasError:          _nameError,
            ),
        2 => _StepDate(
              isCountingDown: _isCountingDown,
              onTypeChanged:  _onTypeChanged,
              calYear:   _calYear,  calMonth:  _calMonth,
              calDay:    _calDay,   calHour:   _calHour,
              calMinute: _calMinute,
              onPrevMonth:   _prevMonth,
              onNextMonth:   _nextMonth,
              onDaySelected: (d) => setState(() => _calDay = d),
              onTimeTap:     _pickTime,
              formattedTime: _fmt12h(_calHour, _calMinute),
            ),
        3 => _StepDetails(
              noteCtrl:     _noteCtrl,
              locationCtrl: _locationCtrl,
              repeatOption: _repeatOption,
              onRepeatTap:  _showRepeatPicker,
              imagePath:    _imagePath,
              onImageTap:   _pickImage,
            ),
        4 => _StepReminder(
              isCountingDown: _isCountingDown,
              selected:       _reminder,
              onSelect:       (r) => setState(() => _reminder = r),
              customWeeks:    _customWeeks,
              customDays:     _customDays,
              customHours:    _customHours,
              customMins:     _customMins,
              onWeeksChanged: (v) => setState(() => _customWeeks = v),
              onDaysChanged:  (v) => setState(() => _customDays  = v),
              onHoursChanged: (v) => setState(() => _customHours = v),
              onMinsChanged:  (v) => setState(() => _customMins  = v),
            ),
        _ => const SizedBox.shrink(),
      };
}

// ── _NavBar ───────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.step, required this.totalSteps,
    required this.onBack, required this.onClose,
  });
  final int step, totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40, height: 40,
              child: AnimatedOpacity(
                opacity: onBack != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 26, color: onSurf, padding: EdgeInsets.zero,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (i) {
                  final filled = i < step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: 7, height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? onSurf : Colors.transparent,
                      border: Border.all(
                        color: onSurf.withValues(alpha: filled ? 1.0 : 0.28),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(
              width: 40, height: 40,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                iconSize: 20, color: onSurf, padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _CtaArea ──────────────────────────────────────────────────────────────────

class _CtaArea extends StatelessWidget {
  const _CtaArea({
    required this.isLastStep, required this.isSkippable,
    required this.saving, required this.onCta, required this.onSkip,
  });
  final bool isLastStep, isSkippable, saving;
  final VoidCallback onCta, onSkip;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: FilledButton(
              onPressed: saving ? null : onCta,
              style: FilledButton.styleFrom(
                backgroundColor: onSurf,
                foregroundColor: theme.colorScheme.surface,
                disabledBackgroundColor: onSurf.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w500),
              ),
              child: saving
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.colorScheme.surface),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isLastStep ? 'Create event' : 'Continue'),
                        if (!isLastStep) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: isSkippable
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: GestureDetector(
            onTap: onSkip,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
              child: Text('Skip this step',
                  style: AppTextStyles.bodyMedium.copyWith(color: muted)),
            ),
          ),
          secondChild: const SizedBox(height: 20),
        ),
      ],
    );
  }
}

// ── Step 1: Name ──────────────────────────────────────────────────────────────

class _StepName extends StatelessWidget {
  const _StepName({
    required this.nameCtrl, required this.category,
    required this.onCategoryChanged, required this.hasError,
  });
  final TextEditingController nameCtrl;
  final String category;
  final ValueChanged<String> onCategoryChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final surfCol = theme.colorScheme.surface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);
    final error  = theme.colorScheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your\nmoment?",
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf,
              fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 36),

          // Name input
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 26, color: onSurf, fontStyle: FontStyle.italic,
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
                  borderSide: BorderSide(
                      color: muted.withValues(alpha: 0.28), width: 1.5)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: hasError ? error : muted.withValues(alpha: 0.28),
                      width: 1.5)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: hasError ? error : onSurf, width: 1.5)),
              contentPadding: const EdgeInsets.only(top: 10, bottom: 14),
            ),
            textInputAction: TextInputAction.done,
          ),

          // Error message
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: hasError
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Give your moment a name to continue.',
                style: AppTextStyles.labelSmall.copyWith(color: error),
              ),
            ),
            secondChild: const SizedBox(height: 0),
          ),

          const SizedBox(height: 28),

          // Category label
          Text(
            'CATEGORY',
            style: AppTextStyles.labelSmall.copyWith(
              color: muted, letterSpacing: 1.6, fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Category pills
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _kCategories.map((cat) {
              final sel = cat == category;
              return GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); onCategoryChanged(cat); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: sel ? onSurf : Colors.transparent,
                    border: Border.all(
                      color: sel ? onSurf : muted.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: sel ? surfCol : muted,
                      fontWeight: FontWeight.w500,
                    ),
                    child: Text(cat),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Step 2: Date + Time ───────────────────────────────────────────────────────

class _StepDate extends StatelessWidget {
  const _StepDate({
    required this.isCountingDown, required this.onTypeChanged,
    required this.calYear,  required this.calMonth,
    required this.calDay,   required this.calHour,
    required this.calMinute,
    required this.onPrevMonth,  required this.onNextMonth,
    required this.onDaySelected, required this.onTimeTap,
    required this.formattedTime,
  });

  final bool isCountingDown;
  final ValueChanged<bool> onTypeChanged;
  final int calYear, calMonth, calDay, calHour, calMinute;
  final VoidCallback onPrevMonth, onNextMonth, onTimeTap;
  final ValueChanged<int> onDaySelected;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When is it?',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf,
              fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 28),

          // Countdown ↔ Count-up toggle
          Container(
            decoration: BoxDecoration(
              color: onSurf.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(child: _TypeBtn(label: 'Counting down to', selected: isCountingDown,  onTap: () { HapticFeedback.selectionClick(); onTypeChanged(true); })),
                Expanded(child: _TypeBtn(label: 'Counting up from', selected: !isCountingDown, onTap: () { HapticFeedback.selectionClick(); onTypeChanged(false); })),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Calendar
          _CalendarWidget(
            year: calYear, month: calMonth, selectedDay: calDay,
            onDaySelected: onDaySelected,
            onPrevMonth: onPrevMonth, onNextMonth: onNextMonth,
            minDate: isCountingDown ? DateTime.now() : null,
          ),
          const SizedBox(height: 12),

          // Time picker row
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: onSurf.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_outlined, size: 18, color: muted),
                  const SizedBox(width: 10),
                  Text('Time',
                      style: AppTextStyles.titleMedium.copyWith(color: onSurf)),
                  const Spacer(),
                  Text(formattedTime,
                      style: AppTextStyles.bodyLarge.copyWith(color: muted)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16,
                      color: muted.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  const _TypeBtn({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: selected
              ? Border.all(color: onSurf.withValues(alpha: 0.10), width: 0.5)
              : null,
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label, textAlign: TextAlign.center,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? onSurf : muted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Calendar widget ───────────────────────────────────────────────────────────

class _CalendarWidget extends StatelessWidget {
  const _CalendarWidget({
    required this.year, required this.month,
    required this.selectedDay, required this.onDaySelected,
    required this.onPrevMonth, required this.onNextMonth,
    this.minDate,
  });

  final int year, month, selectedDay;
  final ValueChanged<int> onDaySelected;
  final VoidCallback onPrevMonth, onNextMonth;
  final DateTime? minDate; // days before this are greyed-out (used for countdown)

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final surfCol = theme.colorScheme.surface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);
    final now    = DateTime.now();

    // Dart weekday: Mon=1…Sun=7 → Sunday-first offset = weekday % 7
    final firstOffset = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final rowCount    = ((firstOffset + daysInMonth) / 7).ceil();

    final todayStart = minDate == null
        ? null
        : DateTime(minDate!.year, minDate!.month, minDate!.day);

    List<Widget> buildRows() {
      final rows = <Widget>[];
      for (var row = 0; row < rowCount; row++) {
        final cells = <Widget>[];
        for (var col = 0; col < 7; col++) {
          final idx = row * 7 + col;
          if (idx < firstOffset || idx >= firstOffset + daysInMonth) {
            cells.add(const Expanded(child: SizedBox(height: 36)));
            continue;
          }
          final day       = idx - firstOffset + 1;
          final cellDate  = DateTime(year, month, day);
          final isDisabled = todayStart != null && cellDate.isBefore(todayStart);
          final isSel      = day == selectedDay;
          final isToday    = now.year == year && now.month == month && now.day == day;

          cells.add(Expanded(
            child: isDisabled
                ? Container(
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                    child: Center(
                      child: Text('$day',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: onSurf.withValues(alpha: 0.2))),
                    ),
                  )
                : GestureDetector(
                    onTap: () => onDaySelected(day),
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSel ? onSurf : Colors.transparent,
                        border: isToday && !isSel
                            ? Border.all(
                                color: onSurf.withValues(alpha: 0.35), width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text('$day',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSel ? surfCol : onSurf,
                              fontWeight: isSel ? FontWeight.w500 : FontWeight.w400,
                            )),
                      ),
                    ),
                  ),
          ));
        }
        if (row > 0) rows.add(const SizedBox(height: 2));
        rows.add(Row(children: cells));
      }
      return rows;
    }

    return Container(
      decoration: BoxDecoration(
        color: onSurf.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              _CalNavBtn(icon: Icons.chevron_left, onTap: onPrevMonth),
              Expanded(
                child: Text(
                  '${_kMonthNames[month - 1]} $year',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium.copyWith(color: onSurf),
                ),
              ),
              _CalNavBtn(icon: Icons.chevron_right, onTap: onNextMonth),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(d,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(color: muted)),
                      ),
                    ))
                .toList(),
          ),
          ...buildRows(),
        ],
      ),
    );
  }
}

class _CalNavBtn extends StatelessWidget {
  const _CalNavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 32, height: 32,
          child: Icon(icon, color: muted, size: 20)),
    );
  }
}

// ── Step 3: Details ───────────────────────────────────────────────────────────

class _StepDetails extends StatelessWidget {
  const _StepDetails({
    required this.noteCtrl, required this.locationCtrl,
    required this.repeatOption, required this.onRepeatTap,
    required this.onImageTap, this.imagePath,
  });

  final TextEditingController noteCtrl, locationCtrl;
  final _RepeatOption repeatOption;
  final VoidCallback onRepeatTap, onImageTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add some detail',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf,
              fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 28),

          // Photo zone
          GestureDetector(
            onTap: onImageTap,
            child: imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(imagePath!), fit: BoxFit.cover),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Change',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomPaint(
                    painter: _DashedBorderPainter(
                        color: muted.withValues(alpha: 0.35),
                        strokeWidth: 1.5, radius: 16),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 32, color: muted),
                          const SizedBox(height: 10),
                          Text('Add a photo',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: muted, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),

          // Note
          _DetailField(
            label: 'Note',
            child: TextField(
              controller: noteCtrl,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(color: onSurf),
              decoration: InputDecoration(
                hintText: 'Add a note…',
                hintStyle: AppTextStyles.bodyLarge
                    .copyWith(color: muted.withValues(alpha: 0.55)),
                filled: false, border: InputBorder.none,
                contentPadding: EdgeInsets.zero, isDense: true,
              ),
              maxLines: 1,
            ),
          ),

          // Repeat — tappable, shows current selection on right
          _DetailField(
            label: 'Repeat',
            onTap: onRepeatTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(repeatOption.label,
                    style: AppTextStyles.bodyLarge.copyWith(color: muted)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 16,
                    color: muted.withValues(alpha: 0.5)),
              ],
            ),
          ),

          // Location
          _DetailField(
            label: 'Location',
            child: TextField(
              controller: locationCtrl,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyLarge.copyWith(color: onSurf),
              decoration: InputDecoration(
                hintText: 'Optional',
                hintStyle: AppTextStyles.bodyLarge
                    .copyWith(color: muted.withValues(alpha: 0.55)),
                filled: false, border: InputBorder.none,
                contentPadding: EdgeInsets.zero, isDense: true,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// Field row with label on left, child on right
class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label, required this.child, this.onTap,
  });
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    Widget row = Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
            color: muted.withValues(alpha: 0.14), width: 0.5)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(label,
                style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      row = GestureDetector(
          onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
    }
    return row;
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  })  : dashLength = 5.0,
        gapLength = 4.0;
  final Color color;
  final double strokeWidth, radius, dashLength, gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final inset = strokeWidth / 2;
    final path  = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
        Radius.circular(radius),
      ));
    for (final m in path.computeMetrics()) {
      var dist = 0.0; var drawing = true;
      while (dist < m.length) {
        final seg = drawing ? dashLength : gapLength;
        if (drawing) canvas.drawPath(m.extractPath(dist, dist + seg), paint);
        dist += seg; drawing = !drawing;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter o) =>
      o.color != color || o.strokeWidth != strokeWidth || o.radius != radius;
}

// ── Step 4: Reminder ──────────────────────────────────────────────────────────

class _StepReminder extends StatelessWidget {
  const _StepReminder({
    required this.isCountingDown,
    required this.selected, required this.onSelect,
    required this.customWeeks, required this.customDays,
    required this.customHours, required this.customMins,
    required this.onWeeksChanged, required this.onDaysChanged,
    required this.onHoursChanged, required this.onMinsChanged,
  });

  final bool isCountingDown;
  final _Reminder selected;
  final ValueChanged<_Reminder> onSelect;
  final int customWeeks, customDays, customHours, customMins;
  final ValueChanged<int> onWeeksChanged, onDaysChanged,
      onHoursChanged, onMinsChanged;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    // Counting-up events only get the Custom option (a fixed "after" reminder)
    final options = isCountingDown
        ? _Reminder.values
        : [_Reminder.custom];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Want a reminder?',
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 32, color: onSurf,
              fontStyle: FontStyle.italic, height: 1.18, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isCountingDown
                ? "We'll send a notification before your moment arrives."
                : "We'll send a notification after your moment begins.",
            style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.5),
          ),
          const SizedBox(height: 24),

          ...options.map((opt) {
            final isSel  = opt == selected;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); onSelect(opt); },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                          color: muted.withValues(alpha: 0.14), width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel
                                  ? onSurf : muted.withValues(alpha: 0.38),
                              width: 1.5,
                            ),
                          ),
                          child: isSel
                              ? Center(
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle, color: onSurf),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Text(opt.label,
                            style: AppTextStyles.bodyLarge.copyWith(
                                color: onSurf)),
                      ],
                    ),
                  ),
                ),

                // Custom time-box expansion
                if (opt == _Reminder.custom && isSel)
                  _CustomReminderBoxes(
                    isCountingDown: isCountingDown,
                    weeks: customWeeks, days: customDays,
                    hours: customHours, mins: customMins,
                    onWeeksChanged: onWeeksChanged,
                    onDaysChanged:  onDaysChanged,
                    onHoursChanged: onHoursChanged,
                    onMinsChanged:  onMinsChanged,
                  ),
              ],
            );
          }),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _CustomReminderBoxes extends StatelessWidget {
  const _CustomReminderBoxes({
    required this.isCountingDown,
    required this.weeks, required this.days,
    required this.hours, required this.mins,
    required this.onWeeksChanged, required this.onDaysChanged,
    required this.onHoursChanged, required this.onMinsChanged,
  });
  final bool isCountingDown;
  final int weeks, days, hours, mins;
  final ValueChanged<int> onWeeksChanged, onDaysChanged,
      onHoursChanged, onMinsChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(38, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCountingDown ? 'How long before?' : 'How long after?',
            style: AppTextStyles.labelSmall.copyWith(
                color: muted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TimeBox(label: 'Weeks', value: weeks,
                  onChanged: onWeeksChanged),
              const SizedBox(width: 8),
              _TimeBox(label: 'Days',  value: days,
                  onChanged: onDaysChanged),
              const SizedBox(width: 8),
              _TimeBox(label: 'Hours', value: hours,
                  onChanged: onHoursChanged),
              const SizedBox(width: 8),
              _TimeBox(label: 'Mins',  value: mins,
                  onChanged: onMinsChanged),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatefulWidget {
  const _TimeBox({
    required this.label, required this.value, required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeBox> createState() => _TimeBoxState();
}

class _TimeBoxState extends State<_TimeBox> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.value == 0 ? '' : '${widget.value}');
  }

  @override
  void didUpdateWidget(_TimeBox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final t = widget.value == 0 ? '' : '${widget.value}';
      if (_ctrl.text != t) _ctrl.text = t;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: onSurf.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 3,
              onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
              style: AppTextStyles.titleMedium.copyWith(color: onSurf),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: AppTextStyles.titleMedium
                    .copyWith(color: muted.withValues(alpha: 0.35)),
                counterText: '',
                filled: false, border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.label,
              style: AppTextStyles.labelSmall.copyWith(color: muted)),
        ],
      ),
    );
  }
}

// ── Repeat bottom sheet ───────────────────────────────────────────────────────

class _RepeatSheet extends StatelessWidget {
  const _RepeatSheet({required this.selected, required this.onSelect});
  final _RepeatOption selected;
  final ValueChanged<_RepeatOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _RepeatOption.values.map((opt) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(opt.label,
                  style: AppTextStyles.bodyLarge.copyWith(color: onSurf)),
              trailing: opt == selected
                  ? Icon(Icons.check, color: onSurf, size: 20) : null,
              onTap: () => onSelect(opt),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Done view ─────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({required this.name, required this.onDone});
  final String name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final muted  = theme.textTheme.bodyMedium?.color ?? onSurf.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 52, color: onSurf),
          const SizedBox(height: 24),
          Text(
            '"$name" was created',
            textAlign: TextAlign.center,
            style: AppTextStyles.frauncesMedium.copyWith(
              fontSize: 28, color: onSurf,
              fontStyle: FontStyle.italic, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "It's been added to your list and your widget will update shortly.",
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: muted, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 56,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: onSurf,
                foregroundColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              child: const Text('Back to moments'),
            ),
          ),
        ],
      ),
    );
  }
}