import '../devices/printer.dart';
import '../l10n/generated/l10n.dart';

/// Die Meldung des Druckers in der Bediensprache. [PrintOutcome.message]
/// bleibt die deutsche Fassung für die Bildschirme, die Deutsch bleiben.
String printProblemText(L10n l, PrintProblem p) => switch (p) {
  PrintProblem.notSetUp => l.printNotSetUp,
  PrintProblem.unreachable => l.printUnreachable,
  PrintProblem.noPermission => l.printNoPermission,
  PrintProblem.paperOut => l.printPaperOut,
  PrintProblem.coverOpen => l.printCoverOpen,
  PrintProblem.timeout => l.printTimeout,
};
