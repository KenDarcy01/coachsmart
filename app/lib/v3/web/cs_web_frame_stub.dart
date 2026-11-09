import 'package:flutter/widgets.dart';

/// Never shown: on iOS and Android NativeWebView uses webview_flutter.
class CsWebFrame extends StatelessWidget {
  const CsWebFrame({super.key, required this.url, this.onClose});
  final String url;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
