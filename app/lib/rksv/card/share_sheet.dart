// Das Teilen-Fenster von Android über den Kanal `kassa/share` (siehe
// ShareChannel.kt): Text an Mail, Messenger und andere Apps.

import 'package:flutter/services.dart';

const shareChannel = MethodChannel('kassa/share');

abstract interface class ShareSheet {
  /// Öffnet das Teilen-Fenster mit [subject] und [text]. `false`, wenn
  /// Android kein Ziel hat.
  Future<bool> text({required String subject, required String text});
}

class ChannelShareSheet implements ShareSheet {
  const ChannelShareSheet({this.channel = shareChannel});

  final MethodChannel channel;

  /// Ohne Kanal oder bei einem Fehler `false`.
  @override
  Future<bool> text({required String subject, required String text}) async {
    try {
      final shown = await channel.invokeMethod<bool>('text', {
        'subject': subject,
        'text': text,
      });
      return shown ?? false;
    } catch (_) {
      return false;
    }
  }
}
