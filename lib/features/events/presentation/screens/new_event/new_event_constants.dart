// new_event_constants.dart

enum Reminder {
  oneWeek('1 week before'),
  oneDay('1 day before'),
  dayOf('Day of'),
  custom('Custom…');

  const Reminder(this.label);
  final String label;
}

enum RepeatOption {
  never('Never'),
  daily('Daily'),
  weekly('Weekly'),
  biweekly('Every 2 weeks'),
  monthly('Monthly'),
  yearly('Yearly');

  const RepeatOption(this.label);
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