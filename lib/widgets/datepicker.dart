import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

typedef OnDateRangeSelected = void Function(DateTimeRange? selectedRange);

class ReusableDatePickerWidget extends StatefulWidget {
  final OnDateRangeSelected onDateSelected;
  final Widget child;
  final DateTimeRange? initialDateRange;

  const ReusableDatePickerWidget({
    Key? key,
    required this.onDateSelected,
    required this.child,
    this.initialDateRange,
  }) : super(key: key);

  @override
  State<ReusableDatePickerWidget> createState() =>
      _ReusableDatePickerWidgetState();
}

class _ReusableDatePickerWidgetState extends State<ReusableDatePickerWidget> {
  late DateTimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedRange =
        widget.initialDateRange ?? DateTimeRange(start: now, end: now);
  }

  void _openDatePicker() {
    DateTimeRange tempRange = _selectedRange;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          final colors = theme.colorScheme;
          final isLightTheme = theme.brightness == Brightness.light;
          final backgroundColor = isLightTheme
              ? Colors.white
              : const Color(0xFF101624);
          final headerColor = isLightTheme
              ? Colors.white
              : const Color(0xFF1E293B);
          final textColor = isLightTheme ? colors.onSurface : Colors.white;
          final mutedTextColor = isLightTheme
              ? colors.onSurfaceVariant
              : Colors.white70;
          final disabledTextColor = isLightTheme
              ? colors.onSurfaceVariant.withOpacity(0.45)
              : Colors.white24;
          final selectionColor = isLightTheme
              ? colors.primary
              : Colors.blueAccent;

          return AlertDialog(
            backgroundColor: backgroundColor,
            title: Text(
              'Select Date Range',
              style: TextStyle(color: textColor),
            ),
            content: SizedBox(
              height: 400,
              width: 320,
              child: Theme(
                data: theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    bodyColor: textColor,
                    displayColor: textColor,
                  ),
                ),
                child: SfDateRangePicker(
                  backgroundColor: backgroundColor,
                  yearCellStyle: DateRangePickerYearCellStyle(
                    textStyle: TextStyle(color: textColor),
                    todayTextStyle: TextStyle(
                      color: selectionColor,
                      fontWeight: FontWeight.bold,
                    ),
                    disabledDatesTextStyle: TextStyle(color: disabledTextColor),
                  ),
                  headerStyle: DateRangePickerHeaderStyle(
                    backgroundColor: headerColor,
                    textAlign: TextAlign.center,
                    textStyle: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  monthViewSettings: DateRangePickerMonthViewSettings(
                    viewHeaderStyle: DateRangePickerViewHeaderStyle(
                      textStyle: TextStyle(
                        color: mutedTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  monthCellStyle: DateRangePickerMonthCellStyle(
                    textStyle: TextStyle(color: textColor),
                    todayTextStyle: TextStyle(
                      color: selectionColor,
                      fontWeight: FontWeight.bold,
                    ),
                    rangeTextStyle: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    weekendTextStyle: TextStyle(color: mutedTextColor),
                    disabledDatesTextStyle: TextStyle(color: disabledTextColor),
                    leadingDatesTextStyle: TextStyle(color: mutedTextColor),
                  ),
                  selectionColor: selectionColor,
                  startRangeSelectionColor: selectionColor,
                  endRangeSelectionColor: selectionColor,
                  rangeSelectionColor: selectionColor.withOpacity(
                    isLightTheme ? 0.2 : 0.35,
                  ),
                  todayHighlightColor: selectionColor,
                  selectionTextStyle: TextStyle(
                    color: isLightTheme ? colors.onPrimary : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  selectionMode: DateRangePickerSelectionMode.range,
                  initialSelectedRange: PickerDateRange(
                    _selectedRange.start,
                    _selectedRange.end,
                  ),
                  onSelectionChanged:
                      (DateRangePickerSelectionChangedArgs args) {
                        if (args.value is PickerDateRange) {
                          final range = args.value as PickerDateRange;
                          if (range.startDate != null) {
                            setDialogState(() {
                              tempRange = DateTimeRange(
                                start: range.startDate!,
                                end: range.endDate ?? range.startDate!,
                              );
                            });
                          }
                        }
                      },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (!mounted) return;

                  setState(
                    () => _selectedRange = DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 30)),
                      end: DateTime.now(),
                    ),
                  );
                  widget.onDateSelected(null);
                },
                child: Text('Clear', style: TextStyle(color: mutedTextColor)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (!mounted) return;
                  setState(() => _selectedRange = tempRange);
                  widget.onDateSelected(tempRange);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectionColor,
                  foregroundColor: isLightTheme
                      ? colors.onPrimary
                      : Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _openDatePicker, child: widget.child);
  }
}
