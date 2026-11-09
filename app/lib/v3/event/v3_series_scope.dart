// "Just this event" or "This and later events" for a recurring series
// (Ken, 2026-11-09). Returns 'one', 'following' or null when dismissed.
import 'package:flutter/material.dart';

import '../v3_theme.dart';

Future<String?> askSeriesScope(BuildContext context,
    {required String action, required int later}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: V3.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      Widget opt(IconData icon, String title, String sub, String value) =>
          ListTile(
            leading: Icon(icon, color: V3.green),
            title: Text(title, style: V3.inter(16, weight: FontWeight.w500)),
            subtitle: Text(sub, style: V3.inter(13, color: V3.muted)),
            onTap: () => Navigator.pop(ctx, value),
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 14, bottom: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFF444A56),
                  borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$action which events?', style: V3.tight(20))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('This event is one of a repeating series.',
                    style: V3.inter(14, color: V3.muted))),
          ),
          opt(Icons.event, 'Just this event', 'The others stay as they are',
              'one'),
          opt(
              Icons.event_repeat,
              'This and later events',
              later > 1
                  ? '$later events from this one on. Earlier ones are left alone.'
                  : 'Only this one is left in the series.',
              'following'),
          const SizedBox(height: 12),
        ]),
      );
    },
  );
}
