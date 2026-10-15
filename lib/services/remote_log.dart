import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Ships log lines to the test log server (shulelogs.php) so problems on
/// TestFlight / release builds can be watched live without a debugger.
///
/// Off unless built with `--dart-define=REMOTE_LOG_URL=...`; never pass it
/// to store builds, the logs carry phone numbers and server bodies.
class RemoteLog {
  static const _url = String.fromEnvironment('REMOTE_LOG_URL');
  static const _token = String.fromEnvironment('REMOTE_LOG_TOKEN');
  static const enabled = _url != '';

  // ponytail: in-memory only, lines still buffered when the app is killed are
  // lost; persist to disk if crash-adjacent lines go missing.
  static const _maxBuffered = 2000;
  static final _session = const Uuid().v4().substring(0, 8);
  static final _start = DateTime.now(); // set on the first add()
  static final _buffer = <String>[];
  static Timer? _timer;
  static bool _sending = false;

  static void add(String line, {String level = 'I'}) {
    if (!enabled) return;
    _buffer.add(
      '${DateTime.now().toIso8601String()} $_session '
      '${Platform.operatingSystem} $level $line',
    );
    _trim();
    _timer ??= Timer.periodic(const Duration(seconds: 2), (_) => _flush());
    // Errors and launch lines go out at once: a native crash right after
    // launch would otherwise kill the app before the first 2s tick.
    if (level == 'E' || DateTime.now().difference(_start).inSeconds < 10) {
      unawaited(_flush());
    }
  }

  static void _trim() {
    if (_buffer.length > _maxBuffered) {
      _buffer.removeRange(0, _buffer.length - _maxBuffered);
    }
  }

  static Future<void> _flush() async {
    if (_sending || _buffer.isEmpty) return;
    _sending = true;
    final batch = List<String>.of(_buffer);
    _buffer.clear();
    try {
      final res = await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'project': 'shuledrive',
              'token': _token,
              'lines': batch,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw StateError('${res.statusCode}');
    } catch (_) {
      // Offline or server down: put the lines back and retry next tick.
      _buffer.insertAll(0, batch);
      _trim();
    } finally {
      _sending = false;
    }
  }
}
