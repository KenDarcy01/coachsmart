// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NativeWebView extends StatefulWidget {
  const NativeWebView({
    super.key,
    this.width,
    this.height,
    required this.url,
    this.onPageReady,
    this.onComplete,
    this.onLogout,
  });

  final double? width;
  final double? height;
  final String url;
  final Future Function()? onPageReady;
  final Future Function()? onComplete;
  final Future Function()? onLogout;

  @override
  State<NativeWebView> createState() => _NativeWebViewState();
}

class _NativeWebViewState extends State<NativeWebView>
    with WidgetsBindingObserver {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // When the app returns to the foreground, check whether the WebView's
  // content process is still alive. On iOS the OS can kill the WKWebView
  // renderer while the app is backgrounded; on Android the same can happen
  // to the WebView renderer. A dead process leaves a blank screen with no
  // way to recover from inside the page, so we detect it here and reload.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndReloadIfDead();
    }
  }

  Future<void> _checkAndReloadIfDead() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    try {
      // A live process returns '1'; a dead process throws a PlatformException.
      await ctrl.runJavaScriptReturningResult('1');
    } catch (_) {
      try {
        ctrl.loadRequest(Uri.parse(widget.url));
      } catch (_) {}
    }
  }

  void _initController() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (JavaScriptMessage msg) {
            final message = msg.message;
            if (message.startsWith('openUrl:')) {
              final url = message.substring('openUrl:'.length);
              try {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {}
              return;
            }
            if (message.startsWith('sharePdf:')) {
              // Format: sharePdf:filename.pdf:BASE64DATA
              final rest = message.substring('sharePdf:'.length);
              final sep = rest.indexOf(':');
              if (sep > 0) {
                final filename = rest.substring(0, sep);
                final b64 = rest.substring(sep + 1);
                try {
                  final bytes = base64Decode(b64);
                  Printing.sharePdf(bytes: bytes, filename: filename);
                } catch (_) {}
              }
              return;
            }
            switch (message) {
              case 'close':
                widget.onLogout?.call();
                break;
              case 'complete':
                widget.onComplete?.call();
                break;
              case 'refreshBadge':
                refreshAppBadge();
                break;
            }
          },
        )
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('/cs-close')) {
              widget.onLogout?.call();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ))
        ..loadRequest(Uri.parse(widget.url));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        color: const Color(0xFF111418),
      );
    }
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      child: WebViewWidget(controller: ctrl),
    );
  }
}
