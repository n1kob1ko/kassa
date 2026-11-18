import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/devices/internet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'Internet: der Strom reicht true und false durch, ohne Kanal true',
    () async {
      var cancelled = false;
      messenger.setMockStreamHandler(
        internetChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events
              ..success(true)
              ..success(false)
              ..success(true);
          },
          onCancel: (arguments) => cancelled = true,
        ),
      );
      addTearDown(() => messenger.setMockStreamHandler(internetChannel, null));

      expect(await ChannelInternet().watch().take(3).toList(), [
        true,
        false,
        true,
      ]);
      await pumpEventQueue();
      expect(cancelled, isTrue);

      messenger.setMockStreamHandler(internetChannel, null);
      expect(await ChannelInternet().watch().first, isTrue);
    },
  );

  test('internetProvider ohne Kanal: true', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final values = <bool>[];
    final sub = container.listen(
      internetProvider,
      (_, next) => next.whenData(values.add),
    );
    addTearDown(sub.close);

    await pumpEventQueue();
    expect(values, [true]);
  });
}
