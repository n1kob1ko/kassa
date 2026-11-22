// Android meldet der Kassa angesteckte Kartenleser (Plan C7): Die Activity
// nimmt USB_DEVICE_ATTACHED für Geräte der Klasse 11 (Chipkarte). Dann bietet
// Android "immer für dieses Gerät öffnen" an, und die Erlaubnis gilt nach dem
// Anstecken von selbst. Die laufende Kassa startet dabei nicht neu
// (singleTop).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final activity = RegExp(
    r'<activity\b.*?</activity>',
    dotAll: true,
  ).firstMatch(manifest)!.group(0)!;

  test('AndroidManifest: die Activity bleibt singleTop', () {
    expect(
      RegExp(r'<activity\b[^>]*>').firstMatch(activity)!.group(0),
      contains('android:launchMode="singleTop"'),
    );
  });

  test('AndroidManifest: ein zweiter intent-filter mit USB_DEVICE_ATTACHED '
      'und meta-data auf den Filter der Kartenleser', () {
    final filters = RegExp(
      r'<intent-filter>(.*?)</intent-filter>',
      dotAll: true,
    ).allMatches(activity).map((m) => m.group(1)!).toList();
    expect(filters, hasLength(2));
    expect(
      filters[0],
      contains('<action android:name="android.intent.action.MAIN"/>'),
    );
    expect(
      filters[1].trim(),
      '<action android:name='
      '"android.hardware.usb.action.USB_DEVICE_ATTACHED"/>',
    );
    final meta = RegExp(
      r'<meta-data\s+android:name="android\.hardware\.usb\.action\.'
      r'USB_DEVICE_ATTACHED"\s+android:resource="([^"]+)"\s*/>',
    ).firstMatch(activity);
    expect(meta, isNotNull);
    expect(meta!.group(1), '@xml/usb_card_reader_filter');
  });

  test('usb_card_reader_filter: genau ein Gerät, Klasse 11', () {
    final filter = File(
      'android/app/src/main/res/xml/usb_card_reader_filter.xml',
    ).readAsStringSync();
    final devices = RegExp(r'<usb-device\b[^>]*/>').allMatches(filter);
    expect(devices.map((m) => m.group(0)), ['<usb-device class="11" />']);
    expect(filter, contains('<resources>'));
  });
}
