import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/custom_code/widgets/index.dart' as custom_widgets;
import '../v3_theme.dart';

/// A full-screen webview page (Matches, Live, Lineup and so on).
///
/// On iOS and Android the page's own back button posts `close` through the
/// FlutterBridge and this pops. In a browser the page sits in an iframe
/// with no bridge, so a slim bar with a back chevron is drawn above it.
class V3WebPage extends StatelessWidget {
  const V3WebPage({super.key, required this.title, required this.url});
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final view = custom_widgets.NativeWebView(
      width: double.infinity,
      height: double.infinity,
      url: url,
      onLogout: () async => Navigator.of(context).maybePop(),
    );
    return Scaffold(
      backgroundColor: V3.bg,
      body: SafeArea(
        child: kIsWeb
            ? Column(children: [
                SizedBox(
                  height: 44,
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          size: 40, color: V3.green),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                        child: Text(title,
                            style: V3.inter(16, weight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 48),
                  ]),
                ),
                Expanded(child: view),
              ])
            : view,
      ),
    );
  }
}
