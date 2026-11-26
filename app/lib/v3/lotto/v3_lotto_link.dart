// Club lotto links open the lotto page in the browser already knowing who
// the user is (Ken, 2026-11-26). The lotto edge function hands out a short
// signed code (action 'handoff', 15 minutes, that lotto only); the page swaps
// it for the user's name and email and shows "Playing as". Nothing else is
// shared, and nothing is saved until they pay.
//
// Codes are fetched ahead of the tap (prefetch) because the iPhone PWA blocks
// a link opened after waiting on the network. In the native app a tap with no
// code ready waits up to 4 seconds for one. Any failure opens the plain link.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart' show launchURL;

class V3LottoLink {
  V3LottoLink._();

  static final _re = RegExp(
      r'^https?://(www\.)?coachsmart\.app/lotto/([a-z0-9-]{2,40})/?(\?.*)?$',
      caseSensitive: false);
  static const _fresh = Duration(minutes: 12);
  static final Map<String, ({String code, DateTime at})> _codes = {};
  static final Map<String, Future<String?>> _pending = {};

  /// The lotto slug if [url] is a CoachSmart club lotto page, else null.
  static String? slugOf(String url) {
    final m = _re.firstMatch(url.trim());
    return m?.group(2)?.toLowerCase();
  }

  /// Fetch codes for any lotto links about to be shown. Safe to call often.
  static void prefetch(Iterable<String> urls) {
    for (final u in urls) {
      final slug = slugOf(u);
      if (slug != null && _ready(slug) == null) unawaited(_fetch(slug));
    }
  }

  /// Open [url]; a lotto link gets the user's sign-in code added.
  static Future<void> open(String url) async {
    final slug = slugOf(url);
    if (slug == null || currentUserUid.isEmpty) {
      await launchURL(url);
      return;
    }
    var code = _ready(slug);
    if (code == null && !kIsWeb) {
      code = await _fetch(slug).timeout(const Duration(seconds: 4),
          onTimeout: () => null);
    }
    if (code == null) {
      if (kIsWeb) unawaited(_fetch(slug));
      await launchURL(url);
      return;
    }
    final uri = Uri.parse(url.trim());
    await launchURL(uri.replace(
        queryParameters: {...uri.queryParameters, 'h': code}).toString());
  }

  static String? _ready(String slug) {
    final c = _codes[slug];
    if (c == null || DateTime.now().difference(c.at) > _fresh) return null;
    return c.code;
  }

  static Future<String?> _fetch(String slug) =>
      _pending[slug] ??= _get(slug).whenComplete(() => _pending.remove(slug));

  static Future<String?> _get(String slug) async {
    try {
      final res = await SupaFlow.client.functions
          .invoke('lotto', body: {'action': 'handoff', 'slug': slug});
      final data = res.data;
      final inner = data is Map ? data['data'] : null;
      final code = inner is Map ? inner['code'] : null;
      if (code is! String || code.isEmpty) return null;
      _codes[slug] = (code: code, at: DateTime.now());
      return code;
    } catch (_) {
      return null;
    }
  }
}
