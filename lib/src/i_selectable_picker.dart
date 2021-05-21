import 'dart:async';

import 'package:flutter/material.dart';

import './enum/day_type.dart';
import 'day_picker.dart' as day_picker;
import 'unselectable_period_error.dart';
import 'utils.dart';

/// Interface for selection logic of the different date pickers.
abstract class ISelectablePicker<T> {
  /// The earliest date the user is permitted to pick.
  /// (only year, month and day matter, time doesn't matter)
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  /// (only year, month and day matter, time doesn't matter)
  final DateTime lastDate;

  /// Function returns if day can be selected or not.
  final SelectableDayPredicate _selectableDayPredicate;

  /// StreamController for new selection (T).
  @protected
  StreamController<T> onUpdateController = StreamController<T>.broadcast();

  /// Stream with new selected (T) event.
  ///
  /// Throws [UnselectablePeriodException]
  /// if there is any custom disabled date in selected.
  Stream<T> get onUpdate => onUpdateController.stream;

  /// Constructor with required fields that used in non-abstract methods
  /// ([isDisabled]).
  ISelectablePicker(this.firstDate, this.lastDate, this._selectableDayPredicate)
      : assert(firstDate != null),
        assert(lastDate != null);

  /// If current selection exists and includes day/days that can't be selected
  /// according to the [_selectableDayPredicate]'
  bool get curSelectionIsCorrupted;

  /// Returns [DayType] for given [day].
  DayType getDayType(DateTime day);

  /// Call when user tap on the day cell.
  void onDayTapped(DateTime selectedDate);

  /// Returns if given day is disabled.
  ///
  /// Returns weather given day before the beginning of the [firstDate]
  /// or after the end of the [lastDate].
  ///
  /// If [_selectableDayPredicate] is set checks it as well.
  @protected
  bool isDisabled(DateTime day) {
    final DateTime beginOfTheFirstDay =
        DatePickerUtils.startOfTheDay(firstDate);
    final DateTime endOfTheLastDay = DatePickerUtils.endOfTheDay(lastDate);
    final bool customDisabled =
        _selectableDayPredicate != null ? !_selectableDayPredicate(day) : false;

    return day.isAfter(endOfTheLastDay) ||
        day.isBefore(beginOfTheFirstDay) ||
        customDisabled;
  }

  /// Closes [onUpdateController].
  /// After it [onUpdateController] can't get new events.
  void dispose() {
    onUpdateController.close();
  }
}

/// Selection logic for [day_picker.DayPicker].
class DaySelectable extends ISelectablePicker<DateTime> {
  /// Currently selected date.
  DateTime selectedDate;

  @override
  bool get curSelectionIsCorrupted => _checkCurSelection();

  /// Creates selection logic for [day_picker.DayPicker].
  ///
  /// Every day can be selected if it is between [firstDate] and [lastDate]
  /// and not unselectable according to the [selectableDayPredicate].
  ///
  /// If day is not selectable according to the [selectableDayPredicate]
  /// nothing will be returned as selection
  /// but [UnselectablePeriodException] will be thrown.
  DaySelectable(this.selectedDate, DateTime firstDate, DateTime lastDate,
      {SelectableDayPredicate selectableDayPredicate})
      : super(firstDate, lastDate, selectableDayPredicate);

  @override
  DayType getDayType(DateTime date) {
    DayType result;

    if (isDisabled(date)) {
      result = DayType.disabled;
    } else if (_isDaySelected(date)) {
      result = DayType.single;
    } else {
      result = DayType.notSelected;
    }

    return result;
  }

  @override
  void onDayTapped(DateTime selectedDate) {
    DateTime newSelected = DatePickerUtils.sameDate(firstDate, selectedDate)
        ? selectedDate
        : DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    onUpdateController.add(newSelected);
  }

  bool _isDaySelected(DateTime date) =>
      DatePickerUtils.sameDate(date, selectedDate);

  // Returns if current selection is disabled
  // according to the [_selectableDayPredicate].
  //
  // Returns false if there is no any selection.
  bool _checkCurSelection() {
    if (selectedDate == null) return false;
    bool selectedIsBroken = _selectableDayPredicate(selectedDate);

    return selectedIsBroken;
  }
}
