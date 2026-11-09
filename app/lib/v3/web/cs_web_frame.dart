// Web frame for the v3 web build (Ken, 2026-11-09: "go for webview changes
// as long as they dont impact the current app").
//
// webview_flutter has no web implementation, so in a browser the
// NativeWebView widget used to stay blank and the v3 pages opened the
// webview URL in a new tab. On web this draws the page in an iframe inside
// the app instead. On iOS and Android the stub is compiled and nothing
// changes. Only app/ (the v3 code) carries this file.
export 'cs_web_frame_stub.dart'
    if (dart.library.js_interop) 'cs_web_frame_web.dart';
