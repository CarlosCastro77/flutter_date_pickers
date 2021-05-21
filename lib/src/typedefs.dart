import 'unselectable_period_error.dart';

/// Signature for function that can be used to handle incorrect selections.
///
/// See also:
/// * [WeekPicker.onSelectionError]
/// * [RangePicker.onSelectionError]
typedef OnSelectionError = void Function(UnselectablePeriodException e);
