import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cbar_parser.dart';

enum CbarFailure {
  /// No connection, DNS failure, TLS failure or timeout.
  offline,

  /// HTTP errors / redirects / empty responses on every day tried.
  server,

  /// A response arrived but held no usable rates.
  parse,
}

class CbarException implements Exception {
  const CbarException(this.failure, [this.detail]);

  final CbarFailure failure;
  final Object? detail;

  @override
  String toString() => 'CbarException($failure, $detail)';
}

/// Downloads the official CBAR daily bulletin.
///
/// Privacy and safety rules: the only request ever made is a GET for a
/// public, dated file on one fixed HTTPS host. No user data, identifiers,
/// cookies or analytics are sent, redirects are not followed (so the
/// request can't be bounced to another host), every attempt has one overall
/// deadline, and the body is read as a stream and dropped past [maxBytes].
/// Failures carry only the exception, never the response body.
///
/// No certificate pinning on purpose: the rates are public and not secret,
/// CBAR rotates its certificates, and a stale pin would silently break the
/// feature. The trust is the system CA store only (network_security_config),
/// plus the plausibility and big-change checks in RateRepository.
class CbarClient {
  CbarClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String host = 'www.cbar.az';
  static const Duration timeout = Duration(seconds: 10);

  /// Largest response body accepted (the real bulletin is ~30 KB). Counted
  /// after HTTP decompression, so a gzip bomb is cut off too.
  static const int maxBytes = CbarParser.maxLength;

  /// A bulletin dated more than this before the requested day is stale or
  /// bogus (the server answers holidays with the last earlier bulletin).
  static const Duration maxAge = Duration(days: 31);

  /// Days tried before today when a bulletin is missing (weekends,
  /// holidays, 404, empty or broken file).
  static const int fallbackDays = 7;

  static Uri urlFor(DateTime day) {
    String two(int v) => v.toString().padLeft(2, '0');
    return Uri(
      scheme: 'https',
      host: host,
      path: '/currencies/${two(day.day)}.${two(day.month)}.${day.year}.xml',
    );
  }

  /// Latest bulletin on or before [today], trying up to [fallbackDays]
  /// earlier days.
  Future<CbarBulletin> fetchLatest(DateTime today) async {
    CbarFailure last = CbarFailure.server;
    Object? detail;
    final DateTime start = DateTime(today.year, today.month, today.day);
    for (int back = 0; back <= fallbackDays; back++) {
      final DateTime day = DateTime(start.year, start.month, start.day - back);
      try {
        final String? body = await _get(urlFor(day));
        if (body == null) {
          last = CbarFailure.server;
          continue;
        }
        final CbarBulletin b = CbarParser.parse(body);
        if (!plausibleDate(b.date, day)) throw const CbarParseException('bulletin date');
        return b;
      } on CbarParseException catch (e) {
        last = CbarFailure.parse;
        detail = e;
      } on SocketException catch (e) {
        throw CbarException(CbarFailure.offline, e);
      } on TlsException catch (e) {
        // Handshake and certificate errors (incl. a MITM proxy's own CA).
        throw CbarException(CbarFailure.offline, e);
      } on TimeoutException catch (e) {
        throw CbarException(CbarFailure.offline, e);
      } on http.ClientException catch (e) {
        throw CbarException(CbarFailure.offline, e);
      }
    }
    throw CbarException(last, detail);
  }

  /// [date] lies within [maxAge] before [requested], or at most one day
  /// after it (time zones).
  static bool plausibleDate(DateTime date, DateTime requested) {
    final DateTime day = DateTime(requested.year, requested.month, requested.day);
    return !date.isAfter(day.add(const Duration(days: 1))) && !date.isBefore(day.subtract(maxAge));
  }

  /// Body of a 200 response, or null for 404 / other status / empty body /
  /// a body over [maxBytes].
  Future<String?> _get(Uri url) async {
    // A real check, not an assert: release builds must never send the
    // request anywhere else.
    if (url.scheme != 'https' || url.host != host || url.hasPort && url.port != 443) {
      throw ArgumentError.value(url, 'url', 'not the CBAR HTTPS host');
    }
    final http.Request req = http.Request('GET', url)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers['Accept'] = 'application/xml';
    final Stopwatch clock = Stopwatch()..start();
    Duration left() {
      final Duration d = timeout - clock.elapsed;
      return d.isNegative ? Duration.zero : d;
    }

    final http.StreamedResponse res = await _client.send(req).timeout(timeout);
    final int? declared = res.contentLength;
    if (res.statusCode != 200 || (declared != null && declared > maxBytes)) {
      // Don't download a body we will not use.
      await _discard(res.stream);
      return null;
    }
    final List<int>? bytes = await _readCapped(res.stream).timeout(left(), onTimeout: () {
      throw TimeoutException('CBAR body', timeout);
    });
    if (bytes == null || bytes.isEmpty) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Collects [s] up to [maxBytes]; cancels the download and returns null as
  /// soon as it grows past that.
  static Future<List<int>?> _readCapped(Stream<List<int>> s) async {
    final BytesBuilder buf = BytesBuilder(copy: false);
    await for (final List<int> chunk in s) {
      if (buf.length + chunk.length > maxBytes) return null; // leaving cancels
      buf.add(chunk);
    }
    return buf.takeBytes();
  }

  static Future<void> _discard(Stream<List<int>> s) async {
    try {
      await s.listen(null).cancel();
    } on Object {
      // Nothing to clean up.
    }
  }

  void close() => _client.close();
}
