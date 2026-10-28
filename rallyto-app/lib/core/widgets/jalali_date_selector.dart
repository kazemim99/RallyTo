import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart' show Jalali;

import '../../config/theme/app_tokens.dart';
import '../constants/app_strings.dart';
import '../utils/jalali_formatter.dart';
import '../utils/persian_digits.dart';

/// A Jalali date picked with three selectors (day, month name, year), in Persian digits. [onChanged] gets the date
/// once all three are chosen, and null while one is missing. A day past the end of the chosen month (31 in Mehr) is
/// pulled back to the month's last day. Whether the date is acceptable (18+, not in the past) is the caller's call.
class JalaliDateSelector extends StatefulWidget {
  const JalaliDateSelector({
    super.key,
    required this.firstYear,
    required this.lastYear,
    required this.onChanged,
    this.value,
    this.newestYearFirst = true,
    this.errorText,
  });

  static const Key dayKey = Key('jalaliDate.day');
  static const Key monthKey = Key('jalaliDate.month');
  static const Key yearKey = Key('jalaliDate.year');

  final int firstYear;
  final int lastYear;
  final Jalali? value;
  final ValueChanged<Jalali?> onChanged;

  /// Birth years read best newest first; dates ahead read best oldest first.
  final bool newestYearFirst;

  /// Shown under the selectors.
  final String? errorText;

  @override
  State<JalaliDateSelector> createState() => _JalaliDateSelectorState();
}

class _JalaliDateSelectorState extends State<JalaliDateSelector> {
  int? _day;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _take(widget.value);
  }

  @override
  void didUpdateWidget(JalaliDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != null && value != oldWidget.value) _take(value);
  }

  void _take(Jalali? value) {
    if (value == null) return;
    _day = value.day;
    _month = value.month;
    _year = value.year;
  }

  int get _daysInMonth {
    final month = _month;
    if (month == null) return 31;
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    final year = _year;
    return year == null ? 30 : Jalali(year, 12).monthLength;
  }

  void _changed({int? day, int? month, int? year}) {
    setState(() {
      _day = day ?? _day;
      _month = month ?? _month;
      _year = year ?? _year;
      final d = _day;
      if (d != null && d > _daysInMonth) _day = _daysInMonth;
    });
    final d = _day;
    final m = _month;
    final y = _year;
    widget.onChanged(d == null || m == null || y == null ? null : Jalali(y, m, d));
  }

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = widget.firstYear; y <= widget.lastYear; y++) y];
    final orderedYears = widget.newestYearFirst ? years.reversed.toList() : years;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _Selector<int>(
                key: JalaliDateSelector.dayKey,
                label: AppStrings.dateDay,
                value: _day,
                items: [for (var d = 1; d <= _daysInMonth; d++) d],
                labelOf: PersianDigits.fromInt,
                onChanged: (day) => _changed(day: day),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 3,
              child: _Selector<int>(
                key: JalaliDateSelector.monthKey,
                label: AppStrings.dateMonth,
                value: _month,
                items: [for (var m = 1; m <= 12; m++) m],
                labelOf: (m) => JalaliFormatter.monthNames[m - 1],
                onChanged: (month) => _changed(month: month),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: 3,
              child: _Selector<int>(
                key: JalaliDateSelector.yearKey,
                label: AppStrings.dateYear,
                value: years.contains(_year) ? _year : null,
                items: orderedYears,
                labelOf: PersianDigits.fromInt,
                onChanged: (year) => _changed(year: year),
              ),
            ),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.errorText!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

class _Selector<T> extends StatelessWidget {
  const _Selector({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // A controlled DropdownButton (not a form field, which keeps its own copy of the value): the day is pulled back
    // when the month gets shorter, and the selector must show it.
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          menuMaxHeight: 320,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ),
    );
  }
}
