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
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';

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
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _speechInitialized = false;
  String? _speechFieldId;
  String _lastRecognizedWords = '';
  bool _voiceHoldActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_speech.isListening) _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechInitialized = true;
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          if (_speechFieldId == null) return;
          _controller?.runJavaScript(
            'window.onSpeechError(${jsonEncode(error.errorMsg)})',
          );
          _speechFieldId = null;
          _voiceHoldActive = false;
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              _speechFieldId != null) {
            if (_speechFieldId == 'voice_input' && _voiceHoldActive) {
              _lastRecognizedWords = '';
              _restartVoiceListen();
            } else {
              final fid = _speechFieldId;
              final words = _lastRecognizedWords;
              _speechFieldId = null;
              _lastRecognizedWords = '';
              if (words.isNotEmpty) {
                _controller?.runJavaScript(
                  'window.receiveSpeechResult(${jsonEncode(fid)}, ${jsonEncode(words)})',
                );
              }
              _controller?.runJavaScript('window.onSpeechDone()');
            }
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _restartVoiceListen() async {
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _lastRecognizedWords = result.recognizedWords;
          }
          if (!result.finalResult && result.recognizedWords.isNotEmpty) {
            _controller?.runJavaScript(
              'window.onVoiceInterim(${jsonEncode(result.recognizedWords)})',
            );
          }
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _lastRecognizedWords = '';
            _controller?.runJavaScript(
              'window.receiveSpeechResult("voice_input", ${jsonEncode(result.recognizedWords)})',
            );
          }
        },
        pauseFor: const Duration(seconds: 30),
        listenFor: const Duration(minutes: 2),
        partialResults: true,
        cancelOnError: false,
      );
    } catch (_) {}
  }

  Future<void> _startSpeech(String fieldId) async {
    if (!_speechInitialized) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      _controller?.runJavaScript(
        'window.onSpeechError(${jsonEncode("Speech recognition not available on this device")})',
      );
      return;
    }
    if (_speech.isListening) await _speech.stop();
    _speechFieldId = fieldId;
    _lastRecognizedWords = '';

    if (fieldId == 'voice_input') {
      _voiceHoldActive = true;
      try {
        await _speech.listen(
          onResult: (result) {
            if (result.recognizedWords.isNotEmpty) {
              _lastRecognizedWords = result.recognizedWords;
            }
            if (!result.finalResult && result.recognizedWords.isNotEmpty) {
              _controller?.runJavaScript(
                'window.onVoiceInterim(${jsonEncode(result.recognizedWords)})',
              );
            }
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              _lastRecognizedWords = '';
              _controller?.runJavaScript(
                'window.receiveSpeechResult("voice_input", ${jsonEncode(result.recognizedWords)})',
              );
            }
          },
          pauseFor: const Duration(seconds: 30),
          listenFor: const Duration(minutes: 2),
          partialResults: true,
          cancelOnError: false,
        );
      } catch (_) {
        _controller?.runJavaScript(
          'window.onSpeechError(${jsonEncode("Could not start microphone")})',
        );
        _speechFieldId = null;
        _voiceHoldActive = false;
      }
    } else {
      try {
        await _speech.listen(
          onResult: (result) {
            if (result.recognizedWords.isNotEmpty) {
              _lastRecognizedWords = result.recognizedWords;
            }
            if (result.finalResult && result.recognizedWords.isNotEmpty) {
              final fid = _speechFieldId;
              if (fid == null) return;
              _speechFieldId = null;
              _lastRecognizedWords = '';
              _controller?.runJavaScript(
                'window.receiveSpeechResult(${jsonEncode(fid)}, ${jsonEncode(result.recognizedWords)})',
              );
              _controller?.runJavaScript('window.onSpeechDone()');
            }
          },
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(minutes: 2),
          partialResults: true,
          cancelOnError: false,
        );
      } catch (_) {
        _controller?.runJavaScript(
          'window.onSpeechError(${jsonEncode("Could not start microphone")})',
        );
        _speechFieldId = null;
      }
    }
  }

  Future<void> _stopSpeech() async {
    if (_speechFieldId == 'voice_input') {
      _voiceHoldActive = false;
      final words = _lastRecognizedWords;
      _speechFieldId = null;
      _lastRecognizedWords = '';
      try {
        await _speech.stop();
      } catch (_) {}
      if (words.isNotEmpty) {
        _controller?.runJavaScript(
          'window.receiveSpeechResult("voice_input", ${jsonEncode(words)})',
        );
      }
      _controller?.runJavaScript('window.onSpeechDone()');
      return;
    }

    final fid = _speechFieldId;
    final words = _lastRecognizedWords;
    _speechFieldId = null;
    _lastRecognizedWords = '';
    try {
      await _speech.stop();
    } catch (_) {}
    if (fid != null) {
      if (words.isNotEmpty) {
        _controller?.runJavaScript(
          'window.receiveSpeechResult(${jsonEncode(fid)}, ${jsonEncode(words)})',
        );
      }
      _controller?.runJavaScript('window.onSpeechDone()');
    }
  }

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
      await ctrl.runJavaScriptReturningResult('1');
    } catch (_) {
      try {
        ctrl.loadRequest(Uri.parse(widget.url));
      } catch (_) {}
    }
  }

  void _initController() {
    try {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent);

      // setOnShowFileSelector is available in webview_flutter >=4.4.0.
      // Called via dynamic dispatch so FlutterFlow's analyser (which runs
      // against an older SDK) does not reject it at edit time, while the
      // actual production build (webview_flutter 4.13.0) resolves it fine.
      try {
        (ctrl as dynamic).setOnShowFileSelector((dynamic params) async {
          try {
            final picker = ImagePicker();
            bool multiple = false;
            try {
              multiple = params.mode.toString().contains('openMultiple');
            } catch (_) {}
            if (multiple) {
              final images = await picker.pickMultiImage();
              return images.map((x) => Uri.file(x.path).toString()).toList();
            } else {
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image == null) return <String>[];
              return [Uri.file(image.path).toString()];
            }
          } catch (_) {
            return <String>[];
          }
        });
      } catch (_) {}

      ctrl
        ..addJavaScriptChannel(
          'FlutterBridge',
          onMessageReceived: (JavaScriptMessage msg) {
            final message = msg.message;
            if (message.startsWith('startSpeech:')) {
              _startSpeech(message.substring('startSpeech:'.length));
              return;
            }
            if (message == 'stopSpeech') {
              _stopSpeech();
              return;
            }
            if (message.startsWith('openUrl:')) {
              final url = message.substring('openUrl:'.length);
              try {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {}
              return;
            }
            if (message.startsWith('sharePdf:')) {
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
        ));
      _controller = ctrl;
      () async {
        try {
          await ctrl.clearCache();
        } catch (_) {}
        if (mounted) ctrl.loadRequest(Uri.parse(widget.url));
      }();
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
      child: WebViewWidget(
        controller: ctrl,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        },
      ),
    );
  }
}
