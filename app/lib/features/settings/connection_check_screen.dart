import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../rksv/card/card_check.dart' show RowResult, RowState;
import '../../rksv/card/card_providers.dart';
import '../../rksv/online/atrust_client.dart';
import '../../rksv/online/connection_check.dart';
import '../../rksv/online/online_providers.dart';
import '../../rksv/rksv_providers.dart';
import '../../rksv/rksv_service.dart';
import '../../ui/pressable.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../kassa/sale_service.dart';
import '../login/session.dart';
import 'card_check_screen.dart';
import 'settings_rows.dart';
import 'signature_panel.dart';

const _shareSubject = 'Kassa: Verbindung zu A-Trust';
const _unexpected = 'Das hat nicht geklappt. Bitte noch einmal.';

const _titles = {
  ConnectionRow.reach: 'A-Trust',
  ConnectionRow.certificate: 'Zertifikat',
  ConnectionRow.login: 'Anmeldung',
  ConnectionRow.signature: 'Probe-Unterschrift',
};

/// Die Seite "Verbindung prüfen" im Bereich Einstellungen, aufgebaut wie
/// "Karte prüfen": links die vier Zeilen von [ConnectionCheck] mit ihren
/// Sätzen, rechts was geprüft wird, "Bericht teilen", "Nochmal prüfen" und,
/// geöffnet mit [ConnectionCheckOpening.enable], "Online-Probe starten".
///
/// Beim Öffnen startet ein Lauf, nur einmal und nur, wenn keiner läuft. Er
/// zählt als Antippen des Chefs nur bei [ConnectionCheckOpening.relogin];
/// "Nochmal prüfen" zählt immer. Der Lauf gehört dem Provider: Wer die Seite
/// verlässt, beendet ihn nicht, und sein Ende ändert hier nichts mehr.
class ConnectionCheckScreen extends ConsumerStatefulWidget {
  const ConnectionCheckScreen({
    super.key,
    required this.opening,
    required this.onBack,
  });

  final ConnectionCheckOpening opening;

  /// Zurück zur Karte "Signatur", auch nach "Online-Probe starten".
  final VoidCallback onBack;

  @override
  ConsumerState<ConnectionCheckScreen> createState() =>
      _ConnectionCheckScreenState();
}

class _ConnectionCheckScreenState extends ConsumerState<ConnectionCheckScreen> {
  bool _sharing = false;
  bool _shareFailed = false;
  bool _starting = false;
  String? _startProblem;

  ConnectionCheck get _check =>
      ref.read(connectionCheckProvider(AtrustSystem.test));

  bool get _offersStart => widget.opening == ConnectionCheckOpening.enable;

  @override
  void initState() {
    super.initState();
    _run(chefTapped: widget.opening == ConnectionCheckOpening.relogin);
  }

  /// "Nochmal prüfen": ein Antippen des Chefs.
  void _retry() {
    if (_check.state.value.running) return;
    setState(() {
      _shareFailed = false;
      _startProblem = null;
    });
    _run(chefTapped: true);
  }

  /// Startet einen Lauf, außer es läuft schon einer. Das Ergebnis kommt über
  /// [ConnectionCheck.state].
  void _run({required bool chefTapped}) {
    final check = _check;
    if (check.state.value.running) return;
    unawaited(
      check
          .run(chefTapped: chefTapped)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  Future<void> _start(ConnectionFacts facts) async {
    if (_starting) return;
    final staff = ref.read(sessionProvider);
    if (staff == null) return;
    final service = ref.read(rksvServiceProvider);
    final sales = ref.read(saleServiceProvider);
    setState(() {
      _starting = true;
      _startProblem = null;
    });
    String? problem;
    try {
      final receipt = await service.enableOnlineProbe(
        staff: staff,
        facts: facts,
      );
      printRksvReceipt(sales, receipt);
    } on RksvProblem catch (e) {
      problem = e.message;
    } on StateError {
      problem = staleSettingsSentence;
    } catch (_) {
      problem = _unexpected;
    }
    if (!mounted) return;
    if (problem == null) {
      widget.onBack();
      return;
    }
    setState(() {
      _starting = false;
      _startProblem = problem;
    });
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    bool shown;
    try {
      shown = await ref
          .read(shareSheetProvider)
          .text(subject: _shareSubject, text: _check.report());
    } catch (_) {
      shown = false;
    }
    if (!mounted) return;
    setState(() {
      _sharing = false;
      _shareFailed = !shown;
    });
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(connectionCheckProvider(AtrustSystem.test));
    return ValueListenableBuilder<ConnectionCheckState>(
      valueListenable: check.state,
      builder: (context, state, _) => _page(context, state),
    );
  }

  Widget _page(BuildContext context, ConnectionCheckState state) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    final running = state.running;
    final finished =
        !running && state.rows[ConnectionRow.reach]!.state != RowState.waiting;
    final facts = state.facts;
    // Die Starttaste steht, solange sie gleich möglich werden kann: während
    // des Laufs gesperrt, nach vier Haken frei. Scheitert der Lauf, wird
    // "Nochmal prüfen" die Hauptaktion.
    final startShown = _offersStart && (running || facts != null);
    final busy = running || _starting;

    final rows = <Widget>[
      for (final row in ConnectionRow.values)
        CheckRowView(
          key: Key('connection-row-${row.name}'),
          signKey: Key('connection-sign-${row.name}'),
          number: row.index + 1,
          title: _titles[row]!,
          result: state.rows[row] ?? const RowResult(RowState.waiting, ''),
        ),
    ];

    final checks = Container(
      padding: const EdgeInsets.symmetric(horizontal: KassaTokens.spaceHuge),
      decoration: checkCardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(
                        top: BorderSide(
                          color: c.line,
                          width: KassaTokens.borderThin,
                        ),
                      ),
              ),
              child: rows[i],
            ),
        ],
      ),
    );

    final retry = KeyedSubtree(
      key: const Key('connection-retry'),
      child: PrimaryButton(
        label: 'Nochmal prüfen',
        filled: !startShown,
        height: startShown ? 64 : 76,
        labelSize: startShown ? 18 : 22,
        onPressed: busy ? null : _retry,
      ),
    );

    final about = Container(
      padding: const EdgeInsets.all(KassaTokens.spaceHuge),
      decoration: checkCardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Was hier geprüft wird',
                    style: text.titleMedium!.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  Text(
                    'Hier siehst du, ob Tablet, Internet und A-Trust '
                    'zusammenarbeiten, und wie lange eine Signatur dauert.',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: KassaTokens.spaceXl),
                  Text(
                    'Das ist das Testsystem von A-Trust. Bons bleiben '
                    'Testbons.',
                    style: text.bodyMedium!.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                      color: c.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_shareFailed) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            const WarnBox(
              'Teilen geht auf diesem Tablet nicht.',
              key: Key('connection-share-failed'),
            ),
          ],
          if (_startProblem case final problem?) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            WarnBox(problem, key: const Key('connection-start-problem')),
          ],
          if (finished) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            KeyedSubtree(
              key: const Key('connection-share'),
              child: PrimaryButton(
                label: 'Bericht teilen',
                filled: false,
                icon: LucideIcons.share,
                height: 64,
                labelSize: 18,
                onPressed: busy || _sharing ? null : _share,
              ),
            ),
          ],
          if (!startShown || !running) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            retry,
          ],
          if (startShown) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            KeyedSubtree(
              key: const Key('connection-start'),
              child: PrimaryButton(
                label: 'Online-Probe starten',
                height: 76,
                labelSize: 22,
                onPressed: busy || facts == null ? null : () => _start(facts),
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      key: const Key('connection-check'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: KassaTokens.receiptHeaderHeight,
          padding: const EdgeInsets.only(left: 6, right: 16),
          child: Row(
            children: [
              Pressable(
                key: const Key('connection-check-back'),
                onTap: widget.onBack,
                semanticLabel: 'Zurück zu den Einstellungen',
                minTapSize: const Size(KassaTokens.minTap, KassaTokens.minTap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.chevronLeft, size: 28, color: c.ink),
                    Text(
                      'Zurück',
                      style: text.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KassaTokens.spaceXxl),
              Expanded(
                child: Text(
                  'Verbindung prüfen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineMedium,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('connection-check-rows'),
                    child: checks,
                  ),
                ),
                const SizedBox(width: KassaTokens.spaceXxl),
                SizedBox(width: 468, child: about),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
