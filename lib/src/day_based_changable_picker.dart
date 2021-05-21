import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'basic_day_based_widget.dart';
import 'date_picker_keys.dart';
import 'date_picker_styles.dart';
import 'day_based_changeable_picker_presenter.dart';
import 'day_picker_selection.dart';
import 'i_selectable_picker.dart';
import 'layout_settings.dart';
import 'month_navigation_row.dart';
import 'semantic_sorting.dart';
import 'typedefs.dart';
import 'utils.dart';

/// Date picker based on [DayBasedPicker] picker (for days, weeks, ranges).
/// Allows select previous/next month.
class DayBasedChangeablePicker<T> extends StatefulWidget {
  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final DayPickerSelection selection;

  /// Called when the user picks a new T.
  final ValueChanged<T> onChanged;

  /// Called when the error was thrown after user selection.
  final OnSelectionError onSelectionError;

  /// The earliest date the user is permitted to pick.
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  final DateTime lastDate;

  /// Layout settings what can be customized by user
  final DatePickerLayoutSettings datePickerLayoutSettings;

  /// Styles what can be customized by user
  final DatePickerStyles datePickerStyles;

  /// Some keys useful for integration tests
  final DatePickerKeys datePickerKeys;

  /// Logic for date selections.
  final ISelectablePicker<T> selectablePicker;

  /// Called when the user changes the month
  final ValueChanged<DateTime> onMonthChanged;

  /// Create picker with option to change month.
  DayBasedChangeablePicker(
      {Key key,
      @required this.selection,
      this.onChanged,
      @required this.firstDate,
      @required this.lastDate,
      @required this.datePickerLayoutSettings,
      @required this.datePickerStyles,
      @required this.selectablePicker,
      this.datePickerKeys,
      this.onSelectionError,
      this.onMonthChanged})
      : assert(datePickerLayoutSettings != null),
        assert(datePickerStyles != null),
        assert(selection != null),
        super(key: key);

  @override
  State<DayBasedChangeablePicker<T>> createState() =>
      _DayBasedChangeablePickerState<T>();
}

// todo: Check initial selection and call onSelectionError in case it has error
// todo: (ISelectablePicker.curSelectionIsCorrupted);
class _DayBasedChangeablePickerState<T>
    extends State<DayBasedChangeablePicker<T>> {
  MaterialLocalizations localizations;
  Locale curLocale;
  TextDirection textDirection;

  DateTime _todayDate;

  // Styles from widget fulfilled with current Theme.
  DatePickerStyles _resultStyles;
  Timer _timer;
  PageController _dayPickerController;
  StreamSubscription<T> _changesSubscription;
  DayBasedChangeablePickerPresenter _presenter;

  @override
  void initState() {
    super.initState();

    // Initially display the pre-selected date.
    final int monthPage = _getInitPage();
    _dayPickerController = PageController(initialPage: monthPage);

    _changesSubscription = widget.selectablePicker.onUpdate
        .listen((newSelectedDate) => widget.onChanged?.call(newSelectedDate))
          ..onError((e) => widget.onSelectionError != null
              ? widget.onSelectionError(e)
              : print(e.toString()));

    _updateCurrentDate();
  }

  @override
  void didUpdateWidget(DayBasedChangeablePicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.datePickerStyles != oldWidget.datePickerStyles) {
      final ThemeData theme = Theme.of(context);
      _resultStyles = widget.datePickerStyles.fulfillWithTheme(theme);
    }

    if (widget.selectablePicker != oldWidget.selectablePicker) {
      _changesSubscription = widget.selectablePicker.onUpdate
          .listen((newSelectedDate) => widget.onChanged?.call(newSelectedDate))
            ..onError((e) => widget.onSelectionError != null
                ? widget.onSelectionError(e)
                : print(e.toString()));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    curLocale = Localizations.localeOf(context);
    textDirection = Directionality.of(context);

    MaterialLocalizations newLocalizations = MaterialLocalizations.of(context);
    if (newLocalizations != localizations) {
      localizations = newLocalizations;
      _initPresenter();
    }

    final ThemeData theme = Theme.of(context);
    _resultStyles = widget.datePickerStyles.fulfillWithTheme(theme);
  }

  @override
  // ignore: prefer_expression_function_bodies
  Widget build(BuildContext context) {
    return Localizations(
      locale: curLocale,
      delegates: GlobalMaterialLocalizations.delegates,
      child: Builder(
        builder: (c) {
          localizations = MaterialLocalizations.of(c);
          return Expanded(
            child: Column(
              children: <Widget>[
                SizedBox(child: _buildMonthNavigationRow()),
                Expanded(
                  child: Semantics(
                    sortKey: MonthPickerSortKey.calendar,
                    child: _buildDayPickerPageView(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dayPickerController?.dispose();
    _changesSubscription.cancel();
    widget.selectablePicker.dispose();
    _presenter.dispose();
    super.dispose();
  }

  void _updateCurrentDate() {
    _todayDate = DateTime.now();
    final DateTime tomorrow =
        DateTime(_todayDate.year, _todayDate.month, _todayDate.day + 1);
    Duration timeUntilTomorrow = tomorrow.difference(_todayDate);
    timeUntilTomorrow +=
        const Duration(seconds: 1); // so we don't miss it by rounding
    _timer?.cancel();
    _timer = Timer(timeUntilTomorrow, () {
      setState(_updateCurrentDate);
    });
  }

  // ignore: prefer_expression_function_bodies
  Widget _buildMonthNavigationRow() {
    return StreamBuilder<DayBasedChangeablePickerState>(
        stream: _presenter.data,
        initialData: _presenter.lastVal,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          DayBasedChangeablePickerState state = snapshot.data;

          return MonthNavigationRow(
            previousPageIconKey: widget.datePickerKeys?.previousPageIconKey,
            nextPageIconKey: widget.datePickerKeys?.nextPageIconKey,
            previousMonthTooltip: state.prevTooltip,
            nextMonthTooltip: state.nextTooltip,
            onPreviousMonthTapped:
                state.isFirstMonth ? null : _presenter.gotoPrevMonth,
            onNextMonthTapped:
                state.isLastMonth ? null : _presenter.gotoNextMonth,
            title: Text(
              state.curMonthDis,
              key: widget.datePickerKeys?.selectedPeriodKeys,
              style: _resultStyles.displayedPeriodTitle,
            ),
            nextIcon: widget.datePickerStyles.nextIcon,
            prevIcon: widget.datePickerStyles.prevIcon,
          );
        });
  }

  Widget _buildDayPickerPageView() => PageView.builder(
        controller: _dayPickerController,
        scrollDirection: Axis.horizontal,
        itemCount:
            DatePickerUtils.monthDelta(widget.firstDate, widget.lastDate) + 1,
        itemBuilder: _buildCalendar,
        onPageChanged: _handleMonthPageChanged,
      );

  Widget _buildCalendar(BuildContext context, int index) {
    final DateTime targetDate =
        DatePickerUtils.addMonthsToMonthDate(widget.firstDate, index);

    return DayBasedPicker(
      key: ValueKey<DateTime>(targetDate),
      selectablePicker: widget.selectablePicker,
      currentDate: _todayDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      displayedMonth: targetDate,
      datePickerLayoutSettings: widget.datePickerLayoutSettings,
      selectedPeriodKey: widget.datePickerKeys?.selectedPeriodKeys,
      datePickerStyles: _resultStyles,
    );
  }

  int _getInitPage() {
    int initPage = 0;

    if (widget.selection.isNotEmpty) {
      initPage = DatePickerUtils.monthDelta(
          widget.firstDate, widget.selection.earliest);
    }

    return initPage;
  }

  void _initPresenter() {
    _presenter = DayBasedChangeablePickerPresenter(
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        localizations: localizations,
        showPrevMonthDates: widget.datePickerLayoutSettings.showPrevMonthEnd,
        showNextMonthDates: widget.datePickerLayoutSettings.showNextMonthStart,
        firstDayOfWeekIndex: widget.datePickerStyles.firstDayOfeWeekIndex);
    _presenter.data.listen(_onStateChanged);

    // date used to define what month should be shown
    DateTime initSelection = widget.firstDate;
    if (widget.selection.isNotEmpty) {
      initSelection = widget.selection.earliest;
    }

    // Give information about initial selection to presenter.
    // It should be done after first frame when PageView is already created.
    // Otherwise event from presenter will cause a error.
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _presenter.setSelectedDate(initSelection);
    });
  }

  void _onStateChanged(DayBasedChangeablePickerState newState) {
    DateTime newMonth = newState.currentMonth;
    final int monthPage =
        DatePickerUtils.monthDelta(widget.firstDate, newMonth);
    _dayPickerController.animateToPage(monthPage,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  void _handleMonthPageChanged(int monthPage) {
    DateTime firstMonth = widget.firstDate;
    DateTime newMonth =
        DateTime(firstMonth.year, firstMonth.month + monthPage, firstMonth.day);
    _presenter?.changeMonth(newMonth);

    widget.onMonthChanged?.call(newMonth);
  }
}
