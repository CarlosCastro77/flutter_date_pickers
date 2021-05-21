import 'date_period.dart';
import 'utils.dart';

/// Base class for day based pickers selection.
abstract class DayPickerSelection {
  /// If this is before [dateTime].
  bool isBefore(DateTime dateTime);

  /// If this is after [dateTime].
  bool isAfter(DateTime dateTime);

  /// Returns earliest [DateTime] in this selection.
  DateTime get earliest;

  /// If this selection is empty.
  bool get isEmpty;

  /// If this selection is not empty.
  bool get isNotEmpty;

  /// Constructor to allow children to have constant constructor.
  const DayPickerSelection();
}

/// Selection with only one selected date.
///
/// See also:
/// * [DayPickerMultiSelection] - selection with one or many single dates.
/// * [DayPickerRangeSelection] - date period selection.
class DayPickerSingleSelection extends DayPickerSelection {
  /// Selected date.
  final DateTime selectedDate;

  /// Creates selection with only one selected date.
  const DayPickerSingleSelection(this.selectedDate)
      : assert(selectedDate != null);

  @override
  bool isAfter(DateTime dateTime) => selectedDate.isAfter(dateTime);

  @override
  bool isBefore(DateTime dateTime) => selectedDate.isAfter(dateTime);

  @override
  DateTime get earliest => selectedDate;

  @override
  bool get isEmpty => selectedDate == null;

  @override
  bool get isNotEmpty => selectedDate != null;
}
