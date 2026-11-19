import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_sync_providers.dart';
import '../../data/outbox_repository.dart';
import '../../data/providers.dart';
import '../../data/sync_state_repository.dart';
import '../../sync/pairing_service.dart';
import '../../sync/server_api.dart';
import '../../ui/primary_button.dart';
import '../../ui/tokens.dart';
import '../kassa/sale_service.dart';
import '../setup/pairing_view.dart' show noStaffText;
import 'pair_question.dart';
import 'settings_rows.dart';

/// Wie lange ein Abgleich her ist: "gerade eben", "vor 2 Minuten",
/// "vor 3 Stunden", "vor 2 Tagen", ohne Abgleich "noch nie".
String lastSyncText(DateTime? at, DateTime now) {
  if (at == null) return 'noch nie';
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'gerade eben';
  if (d.inHours < 1) {
    final m = d.inMinutes;
    return m == 1 ? 'vor 1 Minute' : 'vor $m Minuten';
  }
  if (d.inDays < 1) {
    final h = d.inHours;
    return h == 1 ? 'vor 1 Stunde' : 'vor $h Stunden';
  }
  final days = d.inDays;
  return days == 1 ? 'vor 1 Tag' : 'vor $days Tagen';
}

String _rejectedText(int n) => n == 1
    ? '1 Eintrag wurde vom Server abgelehnt. Niko weiß Bescheid.'
    : '$n Einträge wurden vom Server abgelehnt. Niko weiß Bescheid.';

enum _Intent { pair, load }

/// Die Karte "Server": Zustand der Verbindung, "Jetzt abgleichen" und das
/// Koppeln eines Tablets, das schon eingerichtet ist.
class ServerPanel extends ConsumerStatefulWidget {
  const ServerPanel({super.key});

  @override
  ConsumerState<ServerPanel> createState() => _ServerPanelState();
}

class _ServerPanelState extends ConsumerState<ServerPanel> {
  Timer? _tick;
  _Intent? _asking;
  bool _syncing = false;
  bool _loading = false;
  bool _loadFailed = false;

  /// "Speisekarte laden" fand am Server keinen Chef: nichts wurde ersetzt.
  bool _noChef = false;

  @override
  void initState() {
    super.initState();
    // "vor 2 Minuten" bleibt richtig, solange die Karte zu sehen ist.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await ref.read(syncServiceProvider).syncNow();
    if (mounted) setState(() => _syncing = false);
  }

  void _ask(_Intent intent) => setState(() {
    _asking = intent;
    _loadFailed = false;
    _noChef = false;
  });

  void _cancel() => setState(() => _asking = null);

  Future<void> _confirm() async {
    final intent = _asking;
    setState(() => _asking = null);
    // Hat inzwischen eine Kartenzahlung begonnen, bleibt alles, wie es ist.
    if (ref.read(activeCardPaymentProvider) != null) return;
    switch (intent) {
      case _Intent.pair:
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => const PairingScreen()));
      case _Intent.load:
        await _load();
      case null:
    }
  }

  /// Holt die Speisekarte mit dem Schlüssel, den die Kassa schon hat. Geht es
  /// gut, ist niemand mehr angemeldet und die Anmeldung erscheint von selbst.
  /// Fehlt der Schlüssel oder lehnt der Server ihn ab, hilft nur neues
  /// Koppeln: das wird festgehalten, dann zeigt die Karte "Neu koppeln".
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _noChef = false;
    });
    try {
      await ref.read(pairingServiceProvider).loadInitial();
    } on NoChefOnServerException {
      if (mounted) setState(() => _noChef = true);
    } on ServerException catch (e) {
      if (e.failure == ServerFailure.unauthorized) {
        await _recordUnauthorized();
      } else if (mounted) {
        setState(() => _loadFailed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _recordUnauthorized() async {
    try {
      await ref
          .read(syncStateRepositoryProvider)
          .setResult(
            at: ref.read(clockProvider).now(),
            error: ServerFailure.unauthorized.name,
          );
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Server';
    if (!ref.watch(hasServerProvider)) {
      return const SettingsCard(
        title: title,
        rows: [_Body(main: 'Diese Version hat keinen Server.')],
      );
    }
    final sync = ref.watch(syncStateProvider).value ?? const SyncState();
    final business = ref.watch(catalogStreamProvider).value?.businessName;
    final now = ref.watch(clockProvider).now();
    final cardPayment = ref.watch(activeCardPaymentProvider) != null;
    final question = _asking == null
        ? null
        : PairQuestion(
            onConfirm: _confirm,
            onCancel: _cancel,
            loadOnly: _asking == _Intent.load,
          );

    // `blocked` zuerst: es geht mit `lastError == 'blocked'` zusammen und
    // zeigt nie die Zeile "letzter Abgleich hat nicht geklappt".
    if (!sync.hasRegister) {
      return SettingsCard(
        title: title,
        rows: [
          question ??
              _Body(
                main: 'Nicht mit dem Server verbunden.',
                button: PrimaryButton(
                  key: const Key('server-pair'),
                  label: 'Mit Server verbinden',
                  height: 56,
                  onPressed: cardPayment ? null : () => _ask(_Intent.pair),
                ),
              ),
        ],
      );
    }
    if (sync.blocked) {
      return SettingsCard(
        title: title,
        trailing: const StatusPill('Gesperrt', ok: false),
        rows: [
          _Body(
            main: 'Diese Kassa wurde in der Verwaltung gesperrt.',
            sub:
                'Bonieren geht weiter. Abgeglichen wird erst wieder, wenn die '
                'Sperre aufgehoben ist.',
            // Wer die Sperre eben aufgehoben hat, will nicht 5 Minuten warten.
            button: PrimaryButton(
              key: const Key('server-recheck'),
              label: 'Nochmal prüfen',
              filled: false,
              height: 56,
              leading: _syncing ? const _Spinner() : null,
              onPressed: _syncing ? null : _sync,
            ),
          ),
        ],
      );
    }
    if (sync.lastError == 'unauthorized') {
      return SettingsCard(
        title: title,
        trailing: const StatusPill('Unbekannt', ok: false),
        rows: [
          question ??
              _Body(
                main: 'Der Server kennt diese Kassa nicht mehr.',
                button: PrimaryButton(
                  key: const Key('server-repair'),
                  label: 'Neu koppeln',
                  height: 56,
                  onPressed: cardPayment ? null : () => _ask(_Intent.pair),
                ),
              ),
        ],
      );
    }
    if (!sync.initialPullDone) {
      return SettingsCard(
        title: title,
        trailing: const StatusPill('Nicht geladen', ok: false),
        rows: [
          question ??
              _Body(
                main:
                    'Die Verbindung steht. Die Speisekarte ist noch nicht '
                    'geladen.',
                warn: _noChef
                    ? noStaffText
                    : _loadFailed
                    ? 'Die Speisekarte konnte nicht geladen werden.'
                    : null,
                button: PrimaryButton(
                  key: const Key('server-load'),
                  label: 'Speisekarte laden',
                  height: 56,
                  leading: _loading ? const _Spinner() : null,
                  onPressed: cardPayment || _loading
                      ? null
                      : () => _ask(_Intent.load),
                ),
              ),
        ],
      );
    }
    const failures = {'offline', 'timeout', 'server', 'local'};
    final failed = failures.contains(sync.lastError);
    final who = business == null ? 'Verbunden' : 'Verbunden mit $business';
    final register = sync.registerName;
    // Solange der Zähler lädt oder scheitert, zeigt die Karte nichts davon.
    final counts =
        ref.watch(outboxCountsProvider).value ??
        const OutboxCounts(pending: 0, rejected: 0);
    return SettingsCard(
      title: title,
      trailing: const StatusPill('Verbunden', ok: true),
      rows: [
        _Body(
          main: register == null ? who : '$who als $register',
          sub: 'Zuletzt abgeglichen ${lastSyncText(sync.lastPullAt, now)}',
          pending: counts.pending > 0 ? 'Wartet noch: ${counts.pending}' : null,
          rejected: counts.rejected > 0 ? _rejectedText(counts.rejected) : null,
          warn: failed
              ? 'Der letzte Abgleich hat nicht geklappt. '
                    'Die Kassa versucht es von selbst wieder.'
              : null,
          button: PrimaryButton(
            key: const Key('server-sync'),
            label: 'Jetzt abgleichen',
            filled: false,
            height: 56,
            leading: _syncing ? const _Spinner() : null,
            onPressed: _syncing ? null : _sync,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.main,
    this.sub,
    this.pending,
    this.rejected,
    this.warn,
    this.button,
  });

  final String main;
  final String? sub;

  /// "Wartet noch: n", gleiche Schrift wie [sub], Zahlen in gleicher Breite.
  final String? pending;

  /// Abgelehnte Einträge, in ruhiger Warnfarbe; bricht um, wird nie gekürzt.
  final String? rejected;
  final String? warn;
  final Widget? button;

  @override
  Widget build(BuildContext context) {
    final c = KassaColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            main,
            style: text.bodyMedium!.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: KassaTokens.spaceXxs),
            Text(
              sub!,
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: c.ink2,
              ),
            ),
          ],
          if (pending != null) ...[
            const SizedBox(height: KassaTokens.spaceXxs),
            Text(
              pending!,
              style: text.bodyMedium!.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.3,
                color: c.ink2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (rejected != null) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            WarnBox(rejected!),
          ],
          if (warn != null) ...[
            const SizedBox(height: KassaTokens.spaceXl),
            WarnBox(warn!),
          ],
          if (button != null) ...[
            const SizedBox(height: KassaTokens.spaceXxl),
            button!,
          ],
        ],
      ),
    );
  }
}

/// Kleiner Ring auf einer ruhigen Taste. Mit "Bewegung reduzieren" steht er
/// still.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Läuft',
      excludeSemantics: true,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          value: still ? 0.3 : null,
          color: KassaColors.of(context).ink,
        ),
      ),
    );
  }
}
