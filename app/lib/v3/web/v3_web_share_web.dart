import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

export 'v3_web_share_stub.dart' show WebShareResult;
import 'v3_web_share_stub.dart' show WebShareResult;

/// Opens the browser's share tray.
///
/// navigator.share is called before this function first waits, so it runs
/// inside the tap that started it, which iPhone Safari insists on. When the
/// browser refuses (the tap was used up by waiting for a file or a link)
/// the result is [WebShareResult.needsTap] and the caller asks for one more
/// tap.
Future<WebShareResult> webShare(
    {String? text,
    String? title,
    Uint8List? bytes,
    String? fileName,
    String? mimeType}) async {
  final nav = web.window.navigator;
  final data = web.ShareData();
  if (bytes != null) {
    final file = web.File([bytes.toJS].toJS, fileName ?? 'file',
        web.FilePropertyBag(type: mimeType ?? 'application/octet-stream'));
    data.files = [file].toJS;
    // iPhone drops the file when text comes with it, so a file goes alone
    // with only its title.
    if (title != null && title.isNotEmpty) data.title = title;
  } else {
    if (text != null) data.text = text;
    if (title != null && title.isNotEmpty) data.title = title;
  }
  final has = (nav as JSObject).has('share');
  if (!has) return WebShareResult.unsupported;
  if (bytes != null) {
    final canShare = (nav as JSObject).has('canShare') && nav.canShare(data);
    if (!canShare) return WebShareResult.unsupported;
  }
  try {
    await nav.share(data).toDart;
    return WebShareResult.shown;
  } catch (e) {
    final name = _errorName(e);
    // AbortError: the tray opened and the user closed it.
    if (name == 'AbortError') return WebShareResult.shown;
    if (name == 'NotAllowedError') return WebShareResult.needsTap;
    return WebShareResult.unsupported;
  }
}

String _errorName(Object e) {
  try {
    final js = e as JSObject;
    if (js.isA<web.DOMException>()) return (js as web.DOMException).name;
  } catch (_) {}
  final s = '$e';
  if (s.contains('AbortError')) return 'AbortError';
  if (s.contains('NotAllowedError')) return 'NotAllowedError';
  return s;
}

/// Saves a file in browsers with no share tray (desktop).
void webDownload(Uint8List bytes, String fileName, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(a);
  a.click();
  a.remove();
  Future.delayed(
      const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
