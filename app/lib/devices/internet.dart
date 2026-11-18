// Ob das Tablet gerade Internet hat. Android meldet es über den Kanal
// `kassa/internet` (siehe InternetChannel.kt).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const internetChannel = EventChannel('kassa/internet');

abstract interface class Internet {
  /// `true`, solange das Standardnetz Internet hat.
  Stream<bool> watch();
}

class ChannelInternet implements Internet {
  ChannelInternet({this.channel = internetChannel});

  final EventChannel channel;

  /// Spricht das Protokoll von [EventChannel] selbst: Fehlt der Kanal
  /// (Tests, andere Plattformen), kommt still `true`, statt dass
  /// `receiveBroadcastStream` einen Fehler meldet.
  @override
  Stream<bool> watch() {
    final messenger = channel.binaryMessenger;
    final calls = MethodChannel(channel.name, channel.codec, messenger);
    late final StreamController<bool> out;
    void add(bool value) {
      if (!out.isClosed) out.add(value);
    }

    out = StreamController<bool>(
      onListen: () async {
        messenger.setMessageHandler(channel.name, (reply) async {
          if (reply == null) {
            await out.close();
          } else {
            try {
              add(channel.codec.decodeEnvelope(reply) == true);
            } on PlatformException {
              // Ein Fehler von Android ändert den letzten Stand nicht.
            }
          }
          return null;
        });
        try {
          await calls.invokeMethod<void>('listen');
        } catch (_) {
          add(true);
        }
      },
      onCancel: () async {
        messenger.setMessageHandler(channel.name, null);
        try {
          await calls.invokeMethod<void>('cancel');
        } catch (_) {
          // Kein Kanal, nichts abzumelden.
        }
      },
    );
    return out.stream;
  }
}

final internetProvider = StreamProvider<bool>(
  (ref) => ChannelInternet().watch(),
);
