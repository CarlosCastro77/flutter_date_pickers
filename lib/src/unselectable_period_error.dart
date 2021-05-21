/// Exception thrown when selected period contains custom disabled days.
class UnselectablePeriodException implements Exception {
  /// Dates inside selected period what can't be selected
  /// according custom rules.
  final List<DateTime> customDisabledDates;

  /// Creates exception that stores dates that can not be selected.
  ///
  /// See also:
  /// *[WeekPicker.onSelectionError]
  /// *[RangePicker.onSelectionError]
  UnselectablePeriodException(this.customDisabledDates);
}
