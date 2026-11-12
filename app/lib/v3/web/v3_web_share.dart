// The browser's own share tray (navigator.share) for the v3 web build.
// On iOS and Android the stub is compiled and share_plus is used instead.
export 'v3_web_share_stub.dart'
    if (dart.library.js_interop) 'v3_web_share_web.dart';
