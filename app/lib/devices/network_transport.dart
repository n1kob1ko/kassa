// Netzwerkdruck: roher ESC/POS-Strom über TCP, meist Port 9100.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'printer.dart';

class NetworkTransport implements PrinterTransport {
  /// [address] ist `host` oder `host:port`, Vorgabe-Port 9100.
  NetworkTransport(String address) {
    final i = address.lastIndexOf(':');
    final port = i < 0 ? null : int.tryParse(address.substring(i + 1));
    if (port != null) {
      host = address.substring(0, i).trim();
      this.port = port;
    } else {
      host = address.trim();
      this.port = 9100;
    }
  }

  late final String host;
  late final int port;

  static const connectLimit = Duration(seconds: 3);
  static const sendLimit = Duration(seconds: 5);
  static const statusLimit = Duration(seconds: 1);

  /// Je Aufruf ein eigener Socket, in jedem Fall wieder geschlossen.
  @override
  Future<void> send(Uint8List bytes) async {
    Socket? socket;
    try {
      await (() async {
        socket = await Socket.connect(host, port, timeout: connectLimit);
        socket!.add(bytes);
        await socket!.flush();
      })().timeout(sendLimit);
    } on TimeoutException {
      throw const PrinterException(PrintProblem.timeout);
    } on SocketException {
      throw const PrinterException(PrintProblem.unreachable);
    } on IOException {
      throw const PrinterException(PrintProblem.unreachable);
    } finally {
      socket?.destroy();
    }
  }

  @override
  Future<int?> status(List<int> request) async {
    Socket? socket;
    try {
      return await (() async {
        socket = await Socket.connect(host, port, timeout: connectLimit);
        socket!.add(request);
        await socket!.flush();
        final answer = await socket!.first;
        return answer.isEmpty ? null : answer.first;
      })().timeout(statusLimit);
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }
}
