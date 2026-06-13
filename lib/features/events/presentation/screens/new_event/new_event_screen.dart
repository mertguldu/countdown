// new_event_screen.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/database/database.dart';
import '../../../../../core/services/notification_service.dart';
import '../../../data/event_repository.dart';
import '../../../domain/event.dart';

import 'new_event_constants.dart';
import 'new_event_shared_widgets.dart';
import 'steps/steps.dart';

class NewEventScreen extends ConsumerStatefulWidget {
  const NewEventScreen({super.key, this.initialEventType});
  final EventType? initialEventType;

  @override
  ConsumerState<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends ConsumerState<NewEventScreen> {
  int  _step            = 1;
  bool _done            = false;
  bool _saving          = false;
  bool _isGoingForward = true;
  String _createdName  = '';

  // ── Event type ────────────────────────────────────────────────────────────
  late EventType _eventType;
  ResetPeriod    _resetPeriod = ResetPeriod.never;

  bool get _isCountingDown => _eventType == EventType.countdown;

  /// Countdown / Countup: 5 steps.  Tally: 4 steps.
  int get _totalSteps => _eventType == EventType.tally ? 4 : 5;

  // ── Step 1 ────────────────────────────────────────────────────────────────
  final _nameCtrl           = TextEditingController();
  final _customCategoryCtrl = TextEditingController();
  String _category          = 'Trips';
  bool   _nameError         = false;

  // ── Step 3 (date) ─────────────────────────────────────────────────────────
  late int _calYear, _calMonth, _calDay;
  int _calHour = 0, _calMinute = 0;

  // ── Step 4 (details) ──────────────────────────────────────────────────────
  final _noteCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  RepeatOption _repeatOption = RepeatOption.never;
  String?       _imagePath;
  final         _picker = ImagePicker();

  // ── Step 5 (reminder) ─────────────────────────────────────────────────────
  Reminder _reminder    = Reminder.oneDay;
  int _customWeeks = 0, _customDays = 1, _customHours = 0, _customMins = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _eventType = widget.initialEventType ?? EventType.countdown;
    final now  = DateTime.now();
    _calYear   = now.year;
    _calMonth  = now.month;
    _calDay    = now.day;
    final next = now.add(const Duration(hours: 1));
    _calHour   = next.hour;
    _calMinute = 0;
    _nameCtrl.addListener(_onNameTyped);
    if (_eventType == EventType.countup) _reminder = Reminder.custom;
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onNameTyped)
      ..dispose();
    _customCategoryCtrl.dispose();
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _onNameTyped() {
    if (_nameError && _nameCtrl.text.trim().isNotEmpty) {
      setState(() => _nameError = false);
    }
  }

  DateTime get _selectedDate =>
      DateTime(_calYear, _calMonth, _calDay, _calHour, _calMinute);

  int get _colorValue => kCategoryColors[_category] ?? 0xFF5C6BC0;

  String _fmt12h(int h, int m) {
    final hr   = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hr:${m.toString().padLeft(2, '0')} $ampm';
  }

  // ── Type change ───────────────────────────────────────────────────────────

  void _onEventTypeChanged(EventType type) {
    setState(() {
      _eventType = type;
      if (type == EventType.countdown) {
        _reminder = Reminder.oneDay;
        final now = DateTime.now();
        if (_selectedDate.isBefore(now)) {
          final next = now.add(const Duration(hours: 1));
          _calYear = now.year; _calMonth = now.month;
          _calDay  = now.day;  _calHour  = next.hour; _calMinute = 0;
        }
      } else if (type == EventType.countup) {
        _reminder = Reminder.custom;
      }
    });
  }

  // ── Date actions ──────────────────────────────────────────────────────────

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
    final max = DateTime(_calYear, _calMonth + 1, 0).day;
    if (_calDay > max) _calDay = max;
    if (_isCountingDown) {
      final now = DateTime.now();
      final d   = DateTime(_calYear, _calMonth, _calDay);
      if (d.isBefore(DateTime(now.year, now.month, now.day))) {
        _calDay = now.day.clamp(1, max);
      }
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _calHour, minute: _calMinute),
    );
    if (t == null || !mounted) return;
    if (_isCountingDown) {
      final now      = DateTime.now();
      final isToday = _calYear == now.year &&
          _calMonth == now.month && _calDay == now.day;
      if (isToday) {
        final picked =
            DateTime(now.year, now.month, now.day, t.hour, t.minute);
        if (!picked.isAfter(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pick a time later than right now.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }
    }
    setState(() { _calHour = t.hour; _calMinute = t.minute; });
  }

  // ── Detail actions ────────────────────────────────────────────────────────

  void _showRepeatPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => RepeatSheet(
        selected: _repeatOption,
        onSelect: (opt) {
          setState(() => _repeatOption = opt);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickImage() async {
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

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next() {
      if (_step == 1) {
        if (_nameCtrl.text.trim().isEmpty) {
          HapticFeedback.heavyImpact();
          setState(() => _nameError = true);
          return;
        }
        if (_category == 'Other' && _customCategoryCtrl.text.trim().isEmpty) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a name for your custom category.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }

      if (_step == 3 &&
          _isCountingDown &&
          !_selectedDate.isAfter(DateTime.now())) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose a date and time in the future.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      if (_step == _totalSteps) {
        _createEvent();
      } else {
        HapticFeedback.selectionClick();
        setState(() { _isGoingForward = true; _step++; });
      }
    }

  void _prev() {
    if (_step > 1) {
      HapticFeedback.selectionClick();
      setState(() { _isGoingForward = false; _step--; });
    }
  }

  // ── Event creation ─────────────────────────────────────────────────────────

  Future<void> _createEvent() async {
    setState(() => _saving = true);

    try {
      await NotificationService.requestPermissions();
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }

    final name     = _nameCtrl.text.trim().isEmpty
        ? 'My moment'
        : _nameCtrl.text.trim();
    final noteText = _noteCtrl.text.trim();

    final finalCategory = _category == 'Other'
        ? (_customCategoryCtrl.text.trim().isEmpty
            ? 'Other'
            : _customCategoryCtrl.text.trim())
        : _category;

    try {
      final repo    = ref.read(eventRepositoryProvider);
      final eventId = await repo.insertEvent(
        EventsCompanion(
          title:      Value(name),
          subtitle:   noteText.isNotEmpty ? Value(noteText) : const Value.absent(),
          category:   Value(finalCategory),
          eventType:  Value(_eventType.name),
          targetDate: _eventType != EventType.tally
              ? Value<DateTime?>(_selectedDate)
              : const Value<DateTime?>(null),
          colorValue: Value(_colorValue),
          photoPath:  _imagePath != null ? Value(_imagePath!) : const Value.absent(),
          resetPeriod: _eventType == EventType.tally
              ? Value(_resetPeriod.name)
              : const Value.absent(),
          // Store repeatPeriod only when a real repeat was chosen.
          // 'never' is represented as NULL so the repeat query can filter
          // efficiently with isNotNull().
          repeatPeriod: (_eventType != EventType.tally &&
                  _repeatOption != RepeatOption.never)
              ? Value(_repeatOption.name)
              : const Value.absent(),
        ),
      );

      if (_eventType != EventType.tally) {
        try {
          await _scheduleNotification(eventId, name);
        } catch (notificationError) {
          debugPrint('Failed to schedule notification: $notificationError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Event saved, but notifications are disabled.')),
            );
          }
        }
      }

      if (mounted) {
        setState(() { _saving = false; _done = true; _createdName = name; });
      }
    } catch (e) {
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
        case Reminder.oneWeek:
          notifDate = _selectedDate.subtract(const Duration(days: 7));
          body = '"$name" is 1 week away!';
        case Reminder.oneDay:
          notifDate = _selectedDate.subtract(const Duration(days: 1));
          body = '"$name" is tomorrow!';
        case Reminder.dayOf:
          notifDate = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day, 9);
          body = 'Today is "$name"!';
        case Reminder.custom:
          final dur = _customDuration();
          if (dur.inMinutes > 0) {
            notifDate = _selectedDate.subtract(dur);
            body = '"$name" is coming up!';
          }
      }
    } else {
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!_done)
              NavBar(
                step:       _step,
                totalSteps: _totalSteps,
                onBack:     _step > 1 ? _prev : null,
                onClose:    () => context.pop(),
              ),

            Expanded(
              child: _done
                  ? DoneView(name: _createdName, onDone: () => context.pop())
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) {
                        final fwd = _isGoingForward;
                        return FadeTransition(
                          opacity: CurvedAnimation(
                              parent: animation, curve: Curves.easeOut),
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: fwd
                                  ? const Offset(0.04, 0)
                                  : const Offset(-0.04, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: animation, curve: Curves.easeOut)),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                          key: ValueKey(_step), child: _buildStep()),
                    ),
            ),

            if (!_done) ...[
              CtaArea(
                isLastStep:  _step == _totalSteps,
                isSkippable: _step == 4 && _eventType != EventType.tally,
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

  // ── Step router ────────────────────────────────────────────────────────────

  Widget _buildStep() {
    if (_step == 1) {
      return StepName(
        nameCtrl:           _nameCtrl,
        customCategoryCtrl: _customCategoryCtrl,
        category:           _category,
        onCategoryChanged:  (c) => setState(() => _category = c),
        hasError:           _nameError,
      );
    }

    if (_step == 2) {
      return StepType(
        selected:  _eventType,
        onChanged: _onEventTypeChanged,
      );
    }

    if (_eventType == EventType.tally) {
      return switch (_step) {
        3 => StepTallyReset(
              selected: _resetPeriod,
              onSelect: (p) => setState(() => _resetPeriod = p),
            ),
        _ => StepDetails(
              noteCtrl:     _noteCtrl,
              locationCtrl: _locationCtrl,
              repeatOption: _repeatOption,
              onRepeatTap:  _showRepeatPicker,
              imagePath:    _imagePath,
              onImageTap:   _pickImage,
              showRepeat:   false,
            ),
      };
    }

    return switch (_step) {
      3 => StepDate(
            isCountingDown: _isCountingDown,
            calYear:   _calYear,  calMonth:  _calMonth,
            calDay:    _calDay,   calHour:   _calHour,
            calMinute: _calMinute,
            onPrevMonth:   _prevMonth,
            onNextMonth:   _nextMonth,
            onDaySelected: (d) => setState(() => _calDay = d),
            onTimeTap:     _pickTime,
            formattedTime: _fmt12h(_calHour, _calMinute),
          ),
      4 => StepDetails(
            noteCtrl:     _noteCtrl,
            locationCtrl: _locationCtrl,
            repeatOption: _repeatOption,
            onRepeatTap:  _showRepeatPicker,
            imagePath:    _imagePath,
            onImageTap:   _pickImage,
            showRepeat:   _isCountingDown, // countup and tally never repeat
          ),
      _ => StepReminder(
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
    };
  }
}