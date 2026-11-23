// Sign-in handover (Ken, 2026-11-23): the club page on coachsmart.app and
// the planner here are different websites, so each kept its own login and
// people signed in twice. The club page now opens the planner with
// #cs_rt=<refresh token>; this picks it up once at start, signs in with it
// and wipes it from the address bar. Only the web build does anything.
export 'v3_handover_stub.dart'
    if (dart.library.js_interop) 'v3_handover_web.dart';
