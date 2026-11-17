import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/providers.dart';
import '../../ui/app_header.dart';
import '../../ui/tokens.dart';
import '../bons/bons_screen.dart';
import '../kassa/kassa_screen.dart';
import '../login/session.dart';

/// Kopfleiste und der gewählte Bereich darunter.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  AppArea _area = AppArea.kassa;

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(sessionProvider);
    final c = KassaColors.of(context);
    if (staff == null) return Scaffold(backgroundColor: c.ground);
    return Scaffold(
      backgroundColor: c.ground,
      body: Column(
        children: [
          AppHeader(
            area: _area,
            onArea: (a) => setState(() => _area = a),
            staffName: staff.name,
            isChef: staff.isChef,
            onStaff: ref.read(sessionProvider.notifier).logout,
            onSettings: () {}, // Einstellungen gibt es noch nicht.
            businessName: ref.watch(catalogProvider).value?.businessName,
          ),
          Expanded(child: _areaWidget(_area)),
        ],
      ),
    );
  }
}

/// Hier wird das Bild eines Bereichs gewählt. Bis ihre Aufgaben fertig sind,
/// zeigen die anderen drei einen leeren Platzhalter.
Widget _areaWidget(AppArea area) {
  switch (area) {
    case AppArea.kassa:
      return const KassaScreen(key: Key('area-kassa'));
    case AppArea.bons:
      return const BonsScreen(key: Key('area-bons'));
    case AppArea.overview:
    case AppArea.items:
    case AppArea.close:
      return _AreaPlaceholder(area);
  }
}

class _AreaPlaceholder extends StatelessWidget {
  const _AreaPlaceholder(this.area) : super(key: null);

  final AppArea area;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: Key('area-${area.name}'),
      color: KassaColors.of(context).ground,
      child: const SizedBox.expand(),
    );
  }
}
