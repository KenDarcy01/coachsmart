import 'package:web/web.dart' as web;

import '/backend/supabase/supabase.dart';

Future<void> adoptHandoverSession() async {
  String? rt;
  try {
    final loc = web.window.location;
    final hash = loc.hash;
    if (!hash.startsWith('#cs_rt=')) return;
    rt = Uri.decodeComponent(hash.substring('#cs_rt='.length));
    // Never leave the token in the address bar or history.
    web.window.history.replaceState(null, '', '${loc.pathname}${loc.search}');
  } catch (_) {
    return;
  }
  if (rt.isEmpty) return;
  try {
    await SupaFlow.client.auth.setSession(rt);
  } catch (_) {
    // Expired or already used: the page asks for a normal sign-in.
  }
}
