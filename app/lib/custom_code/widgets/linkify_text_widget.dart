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

import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifyTextWidget extends StatelessWidget {
  const LinkifyTextWidget({
    super.key,
    this.width,
    this.height,
    required this.text,
    required this.textColor,
    required this.linkColor,
    required this.fontSize,
  });

  final double? width;
  final double? height;
  final String text;
  final Color textColor;
  final Color linkColor;
  final double fontSize;

  static final _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      softWrap: true,
      overflow: TextOverflow.visible,
      text: TextSpan(
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          height: 1.5,
        ),
        children: _buildSpans(),
      ),
    );
  }
}
