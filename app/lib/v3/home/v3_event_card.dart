// One event on the v3 home list. Layout follows CHOSEN-home.png:
// left column = club crest, time, meet/countdown; right = team + squad chip,
// title, meta line, attendance bar (or Attending / Decline buttons), pills.
import 'package:flutter/material.dart';
import '/backend/schema/structs/index.dart';
import '../v3_theme.dart';
import 'v3_home_data.dart';

class V3EventCard extends StatelessWidget {
  const V3EventCard({
    super.key,
    required this.event,
    required this.now,
    required this.isNext,
    required this.isCoach,
    required this.far,
    required this.expanded,
    required this.busy,
    this.crestUrl,
    required this.onTap,
    required this.onReply,
    required this.onExpand,
  });

  final EventsStruct event;
  final DateTime now;
  final bool isNext; // the first upcoming event gets the big green card
  final bool isCoach; // role 30+ on this team: show who's missing
  final bool far; // Next week / Later: show the date instead of meet time
  final bool expanded; // Reply pill tapped: show the buttons
  final bool busy; // a reply is being saved
  final String? crestUrl;
  final VoidCallback onTap;
  final void Function(int responseId) onReply;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final t = eventLocalTime(e);
    final cancelled = isCancelled(e);
    final unanswered = needsReply(e);
    final showButtons = unanswered && (isNext || expanded);

    final leftSub = isNext && t != null
        ? countdown(t, now)
        : far && t != null
            ? _dayText(t)
            : e.meetTime.trim().isNotEmpty
                ? 'Meet ${e.meetTime.trim()}'
                : e.eventType;

    final strike = cancelled ? TextDecoration.lineThrough : null;

    return Opacity(
      opacity: cancelled ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: isNext ? Border.all(color: V3.nextLine, width: 1.5) : null,
          gradient: isNext
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [V3.nextTop, V3.card])
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left column
                Container(
                  width: 84,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: V3.line)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (crestUrl != null && crestUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Image.network(crestUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink()),
                          ),
                        ),
                      Text(t == null ? '--:--' : hhmm(t),
                          style: V3.tight(isNext ? 26 : 24,
                                  weight: FontWeight.w700, height: 1)
                              .copyWith(decoration: strike)),
                      const SizedBox(height: 5),
                      Text(leftSub.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: V3.inter(11.5,
                              weight: FontWeight.w500,
                              color: V3.muted,
                              letterSpacing: .5)),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _teamLine(cancelled),
                        const SizedBox(height: 4),
                        Text(e.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V3.inter(18, weight: FontWeight.w600)
                                .copyWith(decoration: strike)),
                        if (_meta(far).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_meta(far),
                              style: V3.inter(14, color: V3.muted)),
                        ],
                        if (e.requestAttendance && !cancelled) ...[
                          if (isNext) ...[
                            const SizedBox(height: 10),
                            _bar(),
                            const SizedBox(height: 7),
                            _legend(),
                          ] else ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _bar()),
                              const SizedBox(width: 10),
                              _countText(),
                            ]),
                          ],
                        ],
                        if (showButtons) ...[
                          const SizedBox(height: 12),
                          _buttons(),
                        ],
                        if (_pills(cancelled, showButtons).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _pills(cancelled, showButtons)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dayText(DateTime t) {
    const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d[t.weekday - 1]} ${t.day} ${m[t.month - 1]}';
  }

  Widget _teamLine(bool cancelled) {
    final e = event;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(e.teamName.toUpperCase(),
              style: V3.inter(13,
                  weight: FontWeight.w700,
                  color: cancelled ? V3.muted : V3.green,
                  letterSpacing: .6,
                  height: 1.4)),
        ),
        if (e.squadName.isNotEmpty && e.squadId != 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(5, 2, 8, 2),
            decoration: BoxDecoration(
                color: V3.card2, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (e.squadImage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ClipOval(
                    child: Image.network(e.squadImage,
                        width: 10,
                        height: 10,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 10, height: 10)),
                  ),
                ),
              Text(e.squadName, style: V3.inter(12, weight: FontWeight.w600)),
            ]),
          ),
        ],
      ],
    );
  }

  String _meta(bool far) {
    final e = event;
    final parts = <String>[];
    if ((isNext || far) && e.meetTime.trim().isNotEmpty) {
      parts.add('Meet ${e.meetTime.trim()}');
    }
    if (e.homeAway.isNotEmpty) parts.add(e.homeAway);
    if (e.locationName.isNotEmpty) parts.add(e.locationName);
    return parts.join(' · ');
  }

  int get _total =>
      event.acceptedCount + event.declinedCount + event.noResponseCount;

  Widget _bar() {
    final e = event;
    final tot = _total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 7,
        child: tot == 0
            ? Container(color: V3.line)
            : Row(children: [
                Expanded(
                    flex: e.acceptedCount, child: Container(color: V3.green)),
                Expanded(
                    flex: e.noResponseCount,
                    child: Container(color: V3.barGrey)),
                Expanded(
                    flex: e.declinedCount, child: Container(color: V3.red)),
              ]),
      ),
    );
  }

  Widget _legend() {
    final e = event;
    Widget item(Color c, int n, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            Text('$n ', style: V3.inter(12.5, weight: FontWeight.w600)),
            Text(label, style: V3.inter(12.5, color: V3.muted)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        item(V3.green, e.acceptedCount, 'attending'),
        item(const Color(0xFF9A9A9A), e.noResponseCount, 'no reply'),
        item(V3.red, e.declinedCount, 'declined'),
      ],
    );
  }

  Widget _countText() {
    final e = event;
    if (isCoach) {
      return RichText(
        text: TextSpan(
          style: V3.inter(14, weight: FontWeight.w500, color: V3.muted),
          children: [
            TextSpan(
                text: '${e.acceptedCount}',
                style: V3.inter(14, weight: FontWeight.w600)),
            const TextSpan(text: ' attending · '),
            TextSpan(
                text: '${e.noResponseCount} no reply',
                style: V3.inter(14,
                    weight: FontWeight.w600, color: V3.amber)),
          ],
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: V3.inter(14, weight: FontWeight.w500, color: V3.muted),
        children: [
          TextSpan(
              text: '${e.acceptedCount}',
              style: V3.inter(14, weight: FontWeight.w600)),
          TextSpan(text: ' of $_total'),
        ],
      ),
    );
  }

  Widget _buttons() {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: busy ? null : () => onReply(3),
            style: FilledButton.styleFrom(
              backgroundColor: V3.green,
              foregroundColor: V3.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check, size: 20),
            label: Text('Attending',
                style: V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => onReply(4),
            style: OutlinedButton.styleFrom(
              foregroundColor: V3.redText,
              side: const BorderSide(color: V3.red, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.close, size: 20),
            label: Text('Decline',
                style:
                    V3.inter(16, weight: FontWeight.w700, color: V3.redText)),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _pills(bool cancelled, bool showButtons) {
    final e = event;
    final out = <Widget>[];
    if (cancelled) {
      out.add(_pill('Cancelled', V3.redTint, V3.redText));
      if (e.eventPaid) out.add(_pill('Paid', V3.greenTint, V3.green));
      return out;
    }
    if (e.eventPaid) out.add(_pill('Paid', V3.greenTint, V3.green));
    if (e.paymentRequired && !e.eventPaid) {
      out.add(_pill('€ Pay', V3.amberTint, V3.amberText, border: V3.amberLine));
    }
    if (e.requestAttendance) {
      if (e.responseId == 3) {
        out.add(_pill('✓ Attending', V3.greenTint, V3.green));
      } else if (e.responseId == 4) {
        out.add(_pill('✗ Declined', V3.redTint, V3.redText));
      } else if (!showButtons) {
        out.add(GestureDetector(
            onTap: onExpand,
            child: _pill('Reply', V3.amber, V3.bg)));
      }
    } else {
      out.add(Text('No reply needed',
          style: V3.inter(13, color: V3.muted, weight: FontWeight.w500)));
    }
    return out;
  }

  Widget _pill(String text, Color bg, Color fg, {Color? border}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Text(text, style: V3.inter(13, weight: FontWeight.w600, color: fg)),
      );
}
