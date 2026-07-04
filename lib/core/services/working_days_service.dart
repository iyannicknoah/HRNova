import '../constants/app_constants.dart';

class WorkingDaysService {
  WorkingDaysService._();

  static int calculate(DateTime start, DateTime end, List<String> workingDays) {
    int count = 0;
    var current = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(last)) {
      final dayName = _dayName(current.weekday);
      final mmdd =
          '${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      if (workingDays.contains(dayName) &&
          !AppConstants.rwandaHolidays.contains(mmdd)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    // Fall back to calendar days so weekends/holidays still count as leave days
    if (count == 0) {
      count = last.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    }
    return count;
  }

  static String _dayName(int weekday) => switch (weekday) {
        1 => 'monday',
        2 => 'tuesday',
        3 => 'wednesday',
        4 => 'thursday',
        5 => 'friday',
        6 => 'saturday',
        7 => 'sunday',
        _ => '',
      };
}
