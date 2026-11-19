import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/error_capture.dart';
import 'data/providers.dart';

/// Gerätemodell und Android-Version für die Berichte. Geht etwas schief,
/// bleiben die Angaben leer.
Future<DeviceInfo> _readDeviceInfo() async {
  try {
    if (!Platform.isAndroid) return const DeviceInfo();
    final info = await DeviceInfoPlugin().androidInfo;
    return DeviceInfo(androidVersion: info.version.release, model: info.model);
  } catch (_) {
    return const DeviceInfo();
  }
}

Future<void> main() async {
  // Binding und runApp laufen in derselben Zone, sonst beschwert sich Flutter.
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final container = ProviderContainer(
        overrides: [
          deviceInfoProvider.overrideWithValue(await _readDeviceInfo()),
        ],
      );
      installErrorCapture(() => container.read(reportRepositoryProvider));
      // Nur Querformat.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const KassaApp(),
        ),
      );
    },
    // Fehler in Futures und Hintergrund-Aufgaben: derselbe Weg wie sonst.
    (error, stack) => PlatformDispatcher.instance.onError?.call(error, stack),
  );
}
