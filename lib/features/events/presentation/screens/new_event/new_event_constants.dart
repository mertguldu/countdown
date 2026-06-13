// new_event_constants.dart
import 'package:flutter/material.dart';
import '../../../domain/event.dart';

// RepeatOption enum lives in domain/event.dart (it needs to be accessible
// from the repository layer). Re-exported implicitly via the import above.

class EventTypeOption {
  final EventType type;
  final IconData icon;
  final String label;
  final String desc;

  const EventTypeOption(this.type, this.icon, this.label, this.desc);
}

const List<EventTypeOption> kEventTypeOptions = [
  EventTypeOption(EventType.countdown, Icons.hourglass_bottom, 'Count-Down', 'Count down to a future date or event'),
  EventTypeOption(EventType.countup, Icons.timelapse, 'Count-Up', 'Track time elapsed since a moment'),
  EventTypeOption(EventType.tally, Icons.add_circle_outline, 'Counter', 'Count how many times something happens'),
];

enum Reminder {
  oneWeek('1 week before'),
  oneDay('1 day before'),
  dayOf('Day of'),
  custom('Custom…');

  const Reminder(this.label);
  final String label;
}

const kCategories = [
  'Trips', 'Birthdays', 'Anniversaries', 'Personal',
  'Work', 'Family', 'Health', 'Other',
];

const kCategoryColors = <String, int>{
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

const kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];