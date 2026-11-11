// One row of the v3 Home timeline: day numeral (first row of a day), the
// rail with its dot, then the event: time, meet time, countdown, tags,
// title, club · team · venue, attendance ring and the reply control.
// Spec: docs/design/home-v3/HOME-V3-DESIGN.md §5.3 to §5.10, §6.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/backend/schema/structs/index.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_home_data.dart';

/// Where the rail sits, measured from the row's left edge: 44 px day column,
/// 4 px gap, then the centre of the 24 px dot column.
const double kRailDayWidth = 44;
const double kRailDotWidth = 24;
const double kRailGap = 4;
const double kRailX = kRailDayWidth + kRailGap + kRailDotWidth / 2;

Color get _railFaint => V3.green.withValues(alpha: .18);
Color get _mutedSpec => const Color(0xFFA1A1A2);

class V3TimelineRow extends StatelessWidget {
  const V3TimelineRow({
    super.key,
    required this.item,
    required this.now,
    required this.isCoach,
    required this.busy,
    required this.firstRow,
    required this.nextDayGreen,
    this.crestUrl,
    required this.clubName,
    required this.onTap,
    required this.onReply,
  });

  final TimelineItem item;
  final DateTime now;
  final bool isCoach; // role 30+ on this team: three equal-weight numbers
  final bool busy; // a reply is being saved
  final bool firstRow; // the rail starts solid green and fades over 120 px
  final bool nextDayGreen; // this row's day numeral is the next event's day
  final String? crestUrl;
  final String clubName;
  final VoidCallback onTap;
  final void Function(int responseId) onReply;

  EventsStruct get e => item.event!;

  @override
  Widget build(BuildContext context) {
    final cancelled = isCancelled(e);
    final top = item.showDay ? 22.0 : 8.0;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: _RailRow(
        firstRow: firstRow,
        extendUp: top,
        day: item.showDay ? _DayMarker(item.day, green: nextDayGreen) : null,
        dot: _Dot(
          next: item.isNext && !cancelled,
          cancelled: cancelled,
          quiet: false,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Crest sits on the team-title line, not in a
                          // column of its own, so the text gets the full
                          // width (Ken, 2026-11-11).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _teamTitle(cancelled)),
                              const SizedBox(width: 10),
                              Opacity(
                                opacity: cancelled ? .45 : 1,
                                child: _crest(),
                              ),
                            ],
                          ),
                          if (_hasSquad) ...[
                            const SizedBox(height: 6),
                            _squadPill(cancelled),
                          ],
                          const SizedBox(height: 6),
                          _line1(cancelled),
                          const SizedBox(height: 3),
                          Text(
                            e.eventTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: V3
                                .inter(
                                  19,
                                  weight: FontWeight.w600,
                                  color: cancelled ? _mutedSpec : V3.text,
                                  height: 1.25,
                                )
                                .copyWith(
                                  decoration: cancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!cancelled && e.requestAttendance) ...[
                  const SizedBox(height: 10),
                  _footer(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Crest from clubs.crest; a circle with the club's initial when missing
  // (never the CoachSmart icon).
  Widget _crest() {
    final initial = clubName.isNotEmpty ? clubName[0].toUpperCase() : '?';
    final fallback = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF252A34),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: V3.tight(16, weight: FontWeight.w700, color: _mutedSpec),
      ),
    );
    return V3CrestImage(crestUrl, size: 48, fallback: fallback);
  }

  // Time · Meet · countdown (next event only) · tags.
  Widget _line1(bool cancelled) {
    final t = item.time;
    final cd = item.isNext && !cancelled ? countdown(t, now) : '';
    final meet = e.meetTime.trim();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(
          hhmm(t),
          style: V3
              .tight(
            22,
            weight: FontWeight.w700,
            color: cancelled ? _mutedSpec : V3.text,
            height: 1.1,
          )
              .copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            decoration: cancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        if (meet.isNotEmpty && !cancelled)
          Text('Meet $meet', style: V3.inter(16, color: _mutedSpec)),
        if (cd.isNotEmpty)
          Text(
            cd,
            style: V3.inter(15, weight: FontWeight.w700, color: V3.green),
          ),
        if (cancelled) const _Tag('Cancelled', green: false),
        if (!cancelled && e.paymentRequired && e.eventPaid)
          const _Tag('Paid', green: true),
      ],
    );
  }

  // Team name in green capitals heads each row so events stand apart
  // (Ken, 2026-11-11). The crest already says which club, so there is no
  // club · team · venue line.
  Widget _teamTitle(bool cancelled) {
    return Text(
      e.teamName.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: V3
          .tight(
            16,
            weight: FontWeight.w800,
            color: cancelled ? _mutedSpec : V3.green,
            height: 1.2,
          )
          .copyWith(letterSpacing: 1.1),
    );
  }

  bool get _hasSquad => e.squadName.isNotEmpty && e.squadId != 0;

  // The squad on its own line as a green-outlined pill with its image,
  // as on the earlier card (Ken, 2026-11-11: make it stand out).
  Widget _squadPill(bool cancelled) {
    final color = cancelled ? _mutedSpec : V3.green;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.squadImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipOval(
                child: Image.network(
                  e.squadImage,
                  width: 18,
                  height: 18,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 18, height: 18),
                ),
              ),
            ),
          Text(
            e.squadName,
            style: V3.inter(
              15,
              weight: FontWeight.w600,
              color: cancelled ? _mutedSpec : V3.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _counts()),
        const SizedBox(width: 10),
        _replyControl(),
      ],
    );
  }

  Widget _counts() {
    final ring = Semantics(
      label: attendanceLabel(e),
      child: _Ring(
        accepted: e.acceptedCount,
        total: e.acceptedCount + e.noResponseCount + e.declinedCount,
      ),
    );
    final tabular = [const FontFeature.tabularFigures()];
    if (isCoach) {
      // Three equal-weight numbers: no reply is the one a coach acts on.
      Widget n(int v, String w) => RichText(
            text: TextSpan(
              style: V3
                  .inter(16, color: _mutedSpec)
                  .copyWith(fontFeatures: tabular),
              children: [
                TextSpan(
                  text: '$v ',
                  style: V3.inter(16, weight: FontWeight.w700, color: V3.text),
                ),
                TextSpan(text: w),
              ],
            ),
          );
      return Row(
        children: [
          ring,
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                n(e.acceptedCount, 'attending'),
                n(e.noResponseCount, 'no reply'),
                n(e.declinedCount, 'declined'),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        ring,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${e.acceptedCount} attending',
                style: V3
                    .inter(16, weight: FontWeight.w600, height: 1.25)
                    .copyWith(fontFeatures: tabular),
              ),
              Text(
                '${e.noResponseCount} no reply · ${e.declinedCount} declined',
                style: V3
                    .inter(14, color: _mutedSpec, height: 1.25)
                    .copyWith(fontFeatures: tabular),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✓ / ✕ pair until answered; then a one-word status that opens the event.
  Widget _replyControl() {
    if (!canReply(e)) return const SizedBox.shrink();
    if (e.responseId == 3) {
      return _status(Icons.check_rounded, 'Attending', V3.green);
    }
    if (e.responseId == 4) {
      return _status(Icons.close_rounded, 'Declined', _mutedSpec);
    }
    final size = isCoach ? 40.0 : 44.0;
    Widget square(
      IconData icon,
      Color color,
      double alpha,
      int id,
      String label,
    ) =>
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: busy ? null : () => onReply(id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: alpha),
                  width: 1.5,
                ),
              ),
              child: busy
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, size: id == 3 ? 20 : 18, color: color),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        square(Icons.check_rounded, V3.green, .55, 3, 'Attending'),
        const SizedBox(width: 6),
        square(Icons.close_rounded, _mutedSpec, .45, 4, 'Declined'),
      ],
    );
  }

  Widget _status(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: V3.inter(
              16,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
}

/// Today's "Nothing on today" row (design §6.6).
class V3QuietDayRow extends StatelessWidget {
  const V3QuietDayRow({super.key, required this.day, required this.firstRow});

  final DateTime day;
  final bool firstRow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: _RailRow(
        firstRow: firstRow,
        extendUp: 22,
        day: _DayMarker(day, green: false),
        dot: const _Dot(next: false, cancelled: false, quiet: true),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Nothing on today',
            style: V3.inter(17, color: _mutedSpec),
          ),
        ),
      ),
    );
  }
}

/// Lays out `44 | 24 | 1fr` with the rail drawn behind the dot column so
/// consecutive rows join into one continuous line.
class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.firstRow,
    required this.extendUp,
    required this.day,
    required this.dot,
    required this.child,
  });

  final bool firstRow;
  final double extendUp; // the row's top padding; the rail covers it too
  final Widget? day;
  final Widget dot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: kRailX - 1,
          top: -extendUp,
          bottom: -10,
          width: 2,
          child: _Rail(fadeFromTop: firstRow),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: kRailDayWidth, child: day ?? const SizedBox()),
            const SizedBox(width: kRailGap),
            SizedBox(
              width: kRailDotWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(child: dot),
              ),
            ),
            const SizedBox(width: kRailGap),
            Expanded(child: child),
          ],
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.fadeFromTop});
  final bool fadeFromTop;

  @override
  Widget build(BuildContext context) {
    if (!fadeFromTop) return Container(color: _railFaint);
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight.isFinite && c.maxHeight > 0 ? c.maxHeight : 120.0;
        final stop = math.min(1.0, 120 / h);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [V3.green, _railFaint, _railFaint],
              stops: [0, stop, 1],
            ),
          ),
        );
      },
    );
  }
}

class _DayMarker extends StatelessWidget {
  const _DayMarker(this.day, {required this.green});
  final DateTime day;
  final bool green;

  static const _wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${day.day}',
          style: V3
              .tight(
            30,
            weight: FontWeight.w800,
            color: green ? V3.green : V3.text,
            height: 1,
          )
              .copyWith(
            letterSpacing: -0.52,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _wd[day.weekday - 1],
          style: V3.inter(
            12,
            weight: FontWeight.w700,
            color: _mutedSpec,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// The rail dot. The next event's dot pulses (unless the system asks for
/// reduced motion); other events get a ringed dot; cancelled a muted ring.
class _Dot extends StatefulWidget {
  const _Dot({
    required this.next,
    required this.cancelled,
    required this.quiet,
  });
  final bool next;
  final bool cancelled;
  final bool quiet;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.next) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _Dot old) {
    super.didUpdateWidget(old);
    if (widget.next && _c == null) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat();
    } else if (!widget.next && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quiet) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: V3.bg,
          border: Border.all(color: _mutedSpec.withValues(alpha: .5), width: 2),
        ),
      );
    }
    if (!widget.next) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: V3.bg,
          border: Border.all(
            color: widget.cancelled ? _mutedSpec : V3.green,
            width: 2,
          ),
        ),
      );
    }
    final solid = Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: V3.green),
    );
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final c = _c;
    if (reduce || c == null) return solid;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        // 0 → 9 px ring, green 55 % → 0, over the first 70 % of the cycle.
        final p = math.min(1.0, c.value / .7);
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: V3.green,
            boxShadow: [
              BoxShadow(
                color: V3.green.withValues(alpha: .55 * (1 - p)),
                spreadRadius: 9 * p,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 26 px attendance ring: green arc for the attending share, faint track.
class _Ring extends StatelessWidget {
  const _Ring({required this.accepted, required this.total});
  final int accepted;
  final int total;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _RingPainter(total == 0 ? 0 : accepted / total),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.75;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = V3.text.withValues(alpha: .12);
    canvas.drawCircle(c, r, track);
    if (fraction <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = V3.green;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// Cancelled / Paid outline tag (design §5.9).
class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.green});
  final String text;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final color = green ? V3.green : _mutedSpec;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: V3.inter(
          13,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: .66,
        ),
      ),
    );
  }
}
