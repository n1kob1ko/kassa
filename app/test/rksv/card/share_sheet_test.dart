import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/rksv/card/share_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'ShareSheet.text reicht Betreff und Text durch; ohne Kanal false',
    () async {
      final calls = <MethodCall>[];
      var answer = true;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        calls.add(call);
        return answer;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
      const sheet = ChannelShareSheet();

      expect(
        await sheet.text(subject: 'Karte prüfen', text: 'Zeile 1\nZeile 2'),
        isTrue,
      );
      expect(calls.single.method, 'text');
      expect(calls.single.arguments, {
        'subject': 'Karte prüfen',
        'text': 'Zeile 1\nZeile 2',
      });

      answer = false;
      expect(await sheet.text(subject: 'a', text: 'b'), isFalse);

      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        throw PlatformException(code: 'io');
      });
      expect(await sheet.text(subject: 'a', text: 'b'), isFalse);

      messenger.setMockMethodCallHandler(shareChannel, null);
      expect(await sheet.text(subject: 'a', text: 'b'), isFalse);
    },
  );
}
