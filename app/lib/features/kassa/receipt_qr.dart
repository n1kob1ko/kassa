import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_info.dart';
import '../../data/delivery_repository.dart';
import '../../data/providers.dart';
import '../../domain/receipt.dart';
import '../../ui/qr_view.dart';
import '../../ui/tokens.dart';

/// Kantenlänge des QR-Codes der Seite eines Bons: mindestens 200 dp, damit
/// eine Handy-Kamera ihn über den Tresen liest.
const receiptQrSize = 220.0;

/// Der QR-Code der Seite des Bons ([receiptPageUrl]), schwarz auf weiß in
/// heller und dunkler Ansicht, mit Ruhezone ([QrView]). Hat der Bon keinen
/// Schlüssel (Bon aus 1.11.0) oder die App keinen Server, steht nichts da.
/// Mit [waitForServer] steht an seiner Stelle ein ruhiger Platzhalter
/// derselben Größe (`receipt-qr-wait`), bis der Server den Bon bestätigt hat;
/// ohne steht der Code sofort da. Zeigt es den Code das erste Mal wirklich,
/// hält es "digital" fest (einmal je Bon, nach dem Bild).
class ReceiptQr extends ConsumerStatefulWidget {
  const ReceiptQr({
    super.key,
    required this.receipt,
    this.waitForServer = true,
    this.qrKey = const Key('receipt-qr'),
  });

  final Receipt receipt;
  final bool waitForServer;

  /// Der Schlüssel des Codes selbst (nicht des Platzhalters).
  final Key qrKey;

  @override
  ConsumerState<ReceiptQr> createState() => _ReceiptQrState();
}

class _ReceiptQrState extends ConsumerState<ReceiptQr> {
  /// "digital" ist für diesen Bon schon angestoßen.
  String? _recordedFor;

  void _record(String receiptId) {
    if (_recordedFor == receiptId) return;
    _recordedFor = receiptId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref
            .read(deliveryRepositoryProvider)
            .record(
              receiptId,
              DeliveryKind.digital,
              at: ref.read(clockProvider).now(),
            );
      } catch (_) {
        // Ein Vermerk; der Code steht trotzdem da.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    final url = receiptPageUrl(
      receipt.publicToken,
      base: ref.watch(serverUrlProvider),
    );
    if (url == null) return const SizedBox.shrink();
    final sent =
        !widget.waitForServer ||
        (ref.watch(receiptSentProvider(receipt.id)).value ?? false);
    if (!sent) {
      final c = KassaColors.of(context);
      return Center(
        child: Container(
          key: const Key('receipt-qr-wait'),
          width: receiptQrSize,
          height: receiptQrSize,
          decoration: BoxDecoration(
            color: c.ground,
            borderRadius: BorderRadius.circular(KassaTokens.radiusMd),
            border: Border.all(color: c.line, width: KassaTokens.borderThin),
          ),
        ),
      );
    }
    _record(receipt.id);
    return Center(
      child: QrView(key: widget.qrKey, data: url, size: receiptQrSize),
    );
  }
}
