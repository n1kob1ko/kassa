// Namen von Monat und Wochentag am Bildschirm, in der Bediensprache. Die
// Zettel (Berichte) nehmen weiter `core/german_dates.dart`.

import '../l10n/generated/l10n.dart';

/// Name des Monats [month] (1 bis 12); Deutsch "Jänner".
String monthName(L10n l, int month) => switch (month) {
  1 => l.dateMonthJanuary,
  2 => l.dateMonthFebruary,
  3 => l.dateMonthMarch,
  4 => l.dateMonthApril,
  5 => l.dateMonthMay,
  6 => l.dateMonthJune,
  7 => l.dateMonthJuly,
  8 => l.dateMonthAugust,
  9 => l.dateMonthSeptember,
  10 => l.dateMonthOctober,
  11 => l.dateMonthNovember,
  12 => l.dateMonthDecember,
  _ => throw RangeError.range(month, 1, 12, 'month'),
};

/// Kurzform des Monats [month] für die Monatstasten ("Jän", "Jan").
String monthShortName(L10n l, int month) => switch (month) {
  1 => l.dateMonthShortJanuary,
  2 => l.dateMonthShortFebruary,
  3 => l.dateMonthShortMarch,
  4 => l.dateMonthShortApril,
  5 => l.dateMonthShortMay,
  6 => l.dateMonthShortJune,
  7 => l.dateMonthShortJuly,
  8 => l.dateMonthShortAugust,
  9 => l.dateMonthShortSeptember,
  10 => l.dateMonthShortOctober,
  11 => l.dateMonthShortNovember,
  12 => l.dateMonthShortDecember,
  _ => throw RangeError.range(month, 1, 12, 'month'),
};

/// Name des Wochentags [weekday] (1 Montag bis 7 Sonntag, wie
/// [DateTime.weekday]).
String weekdayName(L10n l, int weekday) => switch (weekday) {
  1 => l.dateWeekdayMonday,
  2 => l.dateWeekdayTuesday,
  3 => l.dateWeekdayWednesday,
  4 => l.dateWeekdayThursday,
  5 => l.dateWeekdayFriday,
  6 => l.dateWeekdaySaturday,
  7 => l.dateWeekdaySunday,
  _ => throw RangeError.range(weekday, 1, 7, 'weekday'),
};

/// Kurzform des Wochentags ("Mo.", "Mon").
String weekdayShortName(L10n l, int weekday) => switch (weekday) {
  1 => l.dateWeekdayShortMonday,
  2 => l.dateWeekdayShortTuesday,
  3 => l.dateWeekdayShortWednesday,
  4 => l.dateWeekdayShortThursday,
  5 => l.dateWeekdayShortFriday,
  6 => l.dateWeekdayShortSaturday,
  7 => l.dateWeekdayShortSunday,
  _ => throw RangeError.range(weekday, 1, 7, 'weekday'),
};

/// "Dienstag, 17. November" (Tag in Ziffern, Reihenfolge nach Sprache).
String weekdayDayMonth(L10n l, DateTime d) => l.dateWeekdayDayMonth(
  weekdayName(l, d.weekday),
  d.day,
  monthName(l, d.month),
);
