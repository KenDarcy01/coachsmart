import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _frameSeq = 0;

/// An iframe showing [url] inside the Flutter web app.
///
/// The webview pages live on coachsmart.app, a different origin, so the
/// FlutterBridge channel the native widget provides does not exist here and
/// the pages run in their plain-browser mode (URL token, no mic bridge).
/// A page that posts the string `close` to its parent window closes this
/// frame through [onClose].
class CsWebFrame extends StatefulWidget {
  const CsWebFrame({super.key, required this.url, this.onClose});
  final String url;
  final VoidCallback? onClose;

  @override
  State<CsWebFrame> createState() => _CsWebFrameState();
}

class _CsWebFrameState extends State<CsWebFrame> {
  late final String _viewType;
  StreamSubscription<web.MessageEvent>? _messages;

  @override
  void initState() {
    super.initState();
    _viewType = 'cs-web-frame-${_frameSeq++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#111418';
      frame.setAttribute('allow',
          'microphone; camera; clipboard-write; clipboard-read; fullscreen; web-share');
      frame.setAttribute('allowfullscreen', 'true');
      return frame;
    });
    _messages = web.window.onMessage.listen((web.MessageEvent e) {
      final data = e.data;
      if (data.isA<JSString>() && (data as JSString).toDart == 'close') {
        widget.onClose?.call();
      }
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
