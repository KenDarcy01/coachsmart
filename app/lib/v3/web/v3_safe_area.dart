// The phone's bottom safe area (the iPhone home bar) for the web build.
// Flutter web reports no safe-area padding, so in the Home Screen app snack
// bars, bottom bars and sheets sat right on the home bar (Ken, 2026-11-11).
// On the web this reads CSS env(safe-area-inset-bottom) (index.html sets
// viewport-fit=cover); on phones the app already gets real padding.
export 'v3_safe_area_stub.dart'
    if (dart.library.js_interop) 'v3_safe_area_web.dart';
