// One way to share on every v3 screen (Ken, 2026-11-12: "open the share
// tray every time and work the same any time a user taps share").
//
// iOS and Android: share_plus opens the phone's share tray, anchored to the
// button on iPad.
// Web (the preview and the PWA on iPhone): the browser's own share tray
// (navigator.share). iPhone Safari only opens it straight from a tap, so
// when a file or link had to be made first and the tap has gone stale, a
// "Ready to share" card comes up and its Share button opens the tray. Only
// browsers with no share tray (desktop) copy the text or save the file.
//
// Every share button calls V3Share.text or V3Share.file; nothing else in
// lib/v3 should call share_plus or Printing.sharePdf.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'v3_theme.dart';
import 'web/v3_web_share.dart';

class V3Share {
  V3Share._();

  /// Shares a message (an invite, a link). [subject] is the email subject.
  static Future<void> text(BuildContext context, String text,
      {String? subject}) async {
    if (kIsWeb) {
      // Called before anything waits, so the tap is still fresh.
      final r = await webShare(text: text, title: subject);
      if (!context.mounted) return;
      switch (r) {
        case WebShareResult.shown:
          return;
        case WebShareResult.needsTap:
          await _readySheet(context, subject ?? 'Message',
              () => webShare(text: text, title: subject), onFail: () {
            _copy(context, text);
          });
        case WebShareResult.unsupported:
          await _copy(context, text);
      }
      return;
    }
    try {
      final r = await SharePlus.instance.share(ShareParams(
          text: text, subject: subject, sharePositionOrigin: _origin(context)));
      if (r.status == ShareResultStatus.unavailable && context.mounted) {
        await _copy(context, text);
      }
    } catch (_) {
      if (context.mounted) await _copy(context, text);
    }
  }

  /// Shares a file (a PDF, a picture). [title] is shown in the tray.
  static Future<void> file(BuildContext context, Uint8List bytes,
      {required String name, required String mimeType, String? title}) async {
    if (kIsWeb) {
      final r = await webShare(
          bytes: bytes, fileName: name, mimeType: mimeType, title: title);
      if (!context.mounted) return;
      switch (r) {
        case WebShareResult.shown:
          return;
        case WebShareResult.needsTap:
          await _readySheet(
              context,
              name,
              () => webShare(
                  bytes: bytes,
                  fileName: name,
                  mimeType: mimeType,
                  title: title), onFail: () {
            _download(context, bytes, name, mimeType);
          });
        case WebShareResult.unsupported:
          _download(context, bytes, name, mimeType);
      }
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: mimeType, name: name)],
          fileNameOverrides: [name],
          title: title,
          subject: title,
          sharePositionOrigin: _origin(context)));
    } catch (_) {
      if (context.mounted)
        _snack(context, 'Could not open sharing', warn: true);
    }
  }

  /// A PDF made by the app.
  static Future<void> pdf(BuildContext context, Uint8List bytes,
          {required String name, String? title}) =>
      file(context, bytes,
          name: name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf',
          mimeType: 'application/pdf',
          title: title);

  // ------------------------------------------------------------- helpers

  static Rect? _origin(BuildContext context) {
    if (!context.mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static Future<void> _copy(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) _snack(context, 'Copied. Paste it into a message.');
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not share', warn: true);
    }
  }

  static void _download(
      BuildContext context, Uint8List bytes, String name, String mimeType) {
    webDownload(bytes, name, mimeType);
    _snack(context, 'Saved to your downloads');
  }

  static void _snack(BuildContext context, String text, {bool warn = false}) {
    final m = ScaffoldMessenger.maybeOf(context);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  /// The one extra tap iPhone needs after a file or link was made.
  static Future<void> _readySheet(BuildContext context, String what,
      Future<WebShareResult> Function() share,
      {required VoidCallback onFail}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ready to share', style: V3.tight(20)),
                const SizedBox(height: 4),
                Text(what,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(14, color: V3.muted)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const ValueKey('v3-share-ready'),
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.green,
                        foregroundColor: V3.bg,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      // share() runs inside this tap.
                      final f = share();
                      Navigator.of(sheet).pop();
                      f.then((r) {
                        if (r != WebShareResult.shown && context.mounted) {
                          onFail();
                        }
                      });
                    },
                    icon: const Icon(Icons.ios_share),
                    label: Text('Share',
                        style: V3.inter(17,
                            weight: FontWeight.w700, color: V3.bg)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }
}
