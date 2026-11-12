import 'dart:typed_data';

/// What happened when the browser was asked to open its share tray.
enum WebShareResult {
  /// The tray opened (shared or closed by the user).
  shown,

  /// The browser refused because the tap was too long ago (iPhone Safari
  /// needs the share to start straight from a tap).
  needsTap,

  /// This browser has no share tray (most desktop browsers).
  unsupported,
}

/// Never called: only the web build uses the browser share tray.
Future<WebShareResult> webShare(
        {String? text,
        String? title,
        Uint8List? bytes,
        String? fileName,
        String? mimeType}) async =>
    WebShareResult.unsupported;

/// Never called off the web.
void webDownload(Uint8List bytes, String fileName, String mimeType) {}
