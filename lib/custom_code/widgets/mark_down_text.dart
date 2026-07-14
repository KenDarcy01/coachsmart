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

class MarkDownText extends StatefulWidget {
  const MarkDownText({
    super.key,
    this.width,
    this.height,
    required this.content,
    this.textColor,
    this.fontSize,
  });

  final double? width;
  final double? height;
  final String content;
  final Color? textColor;
  final double? fontSize;

  @override
  State<MarkDownText> createState() => _MarkDownTextState();
}

class _MarkDownTextState extends State<MarkDownText> {
  // ' * ' mid-sentence is a bullet separator — convert to newline bullets
  // but leave '**' bold markers alone
  String _normalize(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?<!\*) \* (?!\*)'),
      (_) => '\n* ',
    );
  }

  List<InlineSpan> _parseInline(String text, TextStyle base) {
    final bold = base.copyWith(fontWeight: FontWeight.bold);
    final parts = text.split('**');
    return [
      for (int i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(text: parts[i], style: i.isOdd ? bold : base),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.textColor ?? Colors.white;
    final size = widget.fontSize ?? 14.0;
    final base = TextStyle(color: color, fontSize: size, height: 1.5);

    final lines = _normalize(widget.content ?? '').split('\n');
    final children = <Widget>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      if (line.startsWith('* ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: base),
              Expanded(
                child: RichText(
                  text:
                      TextSpan(children: _parseInline(line.substring(2), base)),
                ),
              ),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(children: _parseInline(line, base)),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
