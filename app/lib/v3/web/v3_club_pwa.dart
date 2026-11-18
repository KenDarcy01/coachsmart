// Club-branded home-screen app for a page (Ken, 2026-11-18): sets the
// browser title, icon and name so "Add to Home Screen" gives e.g.
// "Clontarf Pitches" with the club crest. Only the web build does anything.
export 'v3_club_pwa_stub.dart'
    if (dart.library.js_interop) 'v3_club_pwa_web.dart';
