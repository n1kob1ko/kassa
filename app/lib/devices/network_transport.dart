// Netzwerkdruck: roher ESC/POS-Strom über TCP, meist Port 9100.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'printer.dart';

class NetworkTransport implements PrinterTransport {
  /// [address] ist `host` oder `host:port`, Vorgabe-Port 9100.
  NetworkTransport(
    String address, {
    @visibleForTesting
    Future<Socket> Function(String, int, Duration)? connector,
  }) : _connect =
           connector ??
           ((host, port, limit) => Socket.connect(host, port, timeout: limit)) {
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

  final Future<Socket> Function(String host, int port, Duration limit) _connect;
  final _open = <Socket>{};
  int _epoch = 0;

  final _clock = Stopwatch()..start();

  /// Ende des laufenden Aufrufs auf [_clock]; `null` ohne [startCall].
  Duration? _deadline;

  late final String host;
  late final int port;

  static const connectLimit = Duration(seconds: 3);

  /// Höchstdauer von [send] ohne [startCall].
  static const sendLimit = Duration(seconds: 5);
  static const statusLimit = Duration(seconds: 1);

  /// Zeit, die [send] noch hat: der Rest des laufenden Aufrufs (beim
  /// Küchenbon bis zu [rasterCallLimit], ein großes Bild braucht länger),
  /// ohne [startCall] [sendLimit].
  Duration _sendBudget() {
    final deadline = _deadline;
    if (deadline == null) return sendLimit;
    final left = deadline - _clock.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Je Aufruf ein eigener Socket, in jedem Fall wieder geschlossen.
  @override
  Future<void> send(Uint8List bytes) async {
    final budget = _sendBudget();
    if (budget <= Duration.zero) {
      throw const PrinterException(PrintProblem.timeout);
    }
    try {
      await _withSocket(budget, (socket) async {
        socket.add(bytes);
        await socket.flush();
      });
    } on TimeoutException {
      throw const PrinterException(PrintProblem.timeout);
    } on SocketException {
      throw const PrinterException(PrintProblem.unreachable);
    } on IOException {
      throw const PrinterException(PrintProblem.unreachable);
    } on _Abandoned {
      throw const PrinterException(PrintProblem.timeout);
    }
  }

  @override
  Future<int?> status(List<int> request) async {
    try {
      return await _withSocket(statusLimit, (socket) async {
        socket.add(request);
        await socket.flush();
        final answer = await socket.first;
        return answer.isEmpty ? null : answer.first;
      });
    } catch (_) {
      return null;
    }
  }

  /// Die Zustandsfrage hat ihre eigene Grenze; [send] nutzt, was vom Aufruf
  /// übrig ist. Nach dem Limit schließt [abandon] alles.
  @override
  void startCall(Duration limit) => _deadline = _clock.elapsed + limit;

  @override
  void abandon() {
    _epoch++;
    _deadline = null;
    for (final s in _open.toList()) {
      s.destroy();
    }
    _open.clear();
  }

  /// Verbindet, führt [body] aus und schließt den Socket in jedem Fall, auch
  /// wenn [limit] schon abgelaufen oder der Aufruf aufgegeben ist, bevor die
  /// Verbindung zustande kommt: dann wird der späte Socket sofort zerstört.
  Future<T> _withSocket<T>(
    Duration limit,
    Future<T> Function(Socket socket) body,
  ) async {
    final epoch = _epoch;
    var finished = false;
    Socket? socket;
    Future<T> work() async {
      try {
        final s = await _connect(host, port, connectLimit);
        socket = s;
        if (finished || epoch != _epoch) {
          s.destroy();
          throw const _Abandoned();
        }
        _open.add(s);
        return await body(s);
      } finally {
        final s = socket;
        if (s != null) {
          s.destroy();
          _open.remove(s);
        }
      }
    }

    try {
      return await work().timeout(limit);
    } finally {
      finished = true;
      socket?.destroy();
    }
  }
}

class _Abandoned implements Exception {
  const _Abandoned();
}
