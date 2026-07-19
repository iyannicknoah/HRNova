import '../constants/app_constants.dart';

const _defaultWorkingDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

const _weekdayNames = {
  1: 'monday', 2: 'tuesday', 3: 'wednesday', 4: 'thursday',
  5: 'friday', 6: 'saturday', 7: 'sunday',
};

/// Whether [day] is a scheduled work day for the company — configured
/// working days minus Rwanda public holidays. Shared by payroll, the
/// dashboard "Absent" tile, and attendance check-in so all three agree on
/// what counts as a working day.
bool isCompanyWorkingDay(DateTime day, List<String>? workingDays) {
  final days = workingDays ?? _defaultWorkingDays;
  final mmdd =
      '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return days.contains(_weekdayNames[day.weekday]) &&
      !AppConstants.rwandaHolidays.contains(mmdd);
}
