// v3 Important message pop-up, Club news cards + sheet (Ken, 2026-11-14;
// news cards 2026-11-26).
// Mockups: /mnt/project-files/coachsmart/app-v3/important-messages/.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../lotto/v3_lotto_link.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_messages_models.dart';

/// The small square the message is "from": the club crest, or the CS mark
/// for CoachSmart-wide messages.
class V3MessageBadge extends StatelessWidget {
  const V3MessageBadge(this.message, {super.key, this.size = 36});
  final AppMessage message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: V3.bg,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: V3.line),
      ),
      child: Text('CS',
          style:
              V3.tight(size * 0.36, weight: FontWeight.w700, color: V3.green)),
    );
    if (message.crest.isEmpty) return cs;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: V3CrestImage(message.crest, size: size, fallback: cs),
    );
  }
}

String _when(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final hm = DateFormat('HH:mm').format(t);
  if (day == today) return 'Today $hm';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $hm';
  return DateFormat('EEE d MMM').format(t);
}

// ---------------------------------------------------------------------------
// Important pop-up

/// Shows each important message in turn. X or "Got it" marks it read for
/// this user (it then never shows again); closing the app first means it
/// shows again on the next open.
Future<void> showImportantMessages(
    BuildContext context, List<AppMessage> messages, MessagesApi api) async {
  if (messages.isEmpty) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Important message',
    barrierColor: const Color(0xB8050709),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _ImportantFlow(messages: messages, api: api),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child),
    ),
  );
}

class _ImportantFlow extends StatefulWidget {
  const _ImportantFlow({required this.messages, required this.api});
  final List<AppMessage> messages;
  final MessagesApi api;

  @override
  State<_ImportantFlow> createState() => _ImportantFlowState();
}

class _ImportantFlowState extends State<_ImportantFlow> {
  int _i = 0;

  void _dismiss() {
    final m = widget.messages[_i];
    // Fire and forget: if it fails the message simply shows again next time.
    unawaited(widget.api.dismiss(m.id).catchError((_) {}));
    if (_i + 1 < widget.messages.length) {
      setState(() => _i++);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.messages.length;
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: V3ImportantCard(
                  key: ValueKey(widget.messages[_i].id),
                  message: widget.messages[_i],
                  position: n > 1 ? '${_i + 1} of $n messages' : '',
                  onDismiss: _dismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class V3ImportantCard extends StatelessWidget {
  const V3ImportantCard(
      {super.key,
      required this.message,
      required this.onDismiss,
      this.position = ''});

  final AppMessage message;
  final VoidCallback onDismiss;
  final String position;

  @override
  Widget build(BuildContext context) {
    final m = message;
    // Club messages wear the club colour (Ken 2026-11-25); CoachSmart green otherwise.
    final accent = m.clubColour ?? V3.green;
    final onAccent =
        accent.computeLuminance() > 0.5 ? V3.bg : const Color(0xFFFFFFFF);
    final fromLine = m.scope == 'all'
        ? 'From CoachSmart'
        : (m.scope == 'club' ? 'From the club' : 'From the team');
    return Material(
      color: V3.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: V3.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 6, color: m.clubColour ?? V3.amber),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
              child: Row(
                children: [
                  V3MessageBadge(m),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.fromName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V3.inter(14, weight: FontWeight.w600)),
                        Text(
                            [fromLine, _when(m.startsAt)]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: V3.inter(12.5, color: V3.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onDismiss,
                    style: IconButton.styleFrom(
                        backgroundColor: V3.card2,
                        fixedSize: const Size(38, 38)),
                    icon: const Icon(Icons.close, color: V3.text, size: 22),
                  ),
                ],
              ),
            ),
            if (m.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: Image.network(
                      m.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: V3.amberTint,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('IMPORTANT',
                      style: V3.inter(11.5,
                          weight: FontWeight.w700,
                          color: V3.amberText,
                          letterSpacing: 0.6)),
                ),
              ),
            ),
            // With a link, tapping the message opens it too (Ken, 2026-11-15).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  m.linkUrl.isEmpty ? null : () => V3LottoLink.open(m.linkUrl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: Text(m.title,
                        style:
                            V3.tight(23, weight: FontWeight.w700, height: 1.2)),
                  ),
                  if (m.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                      child: Text(m.body,
                          style: V3.inter(15,
                              color: const Color(0xFFD5D8DE), height: 1.5)),
                    ),
                ],
              ),
            ),
            if (m.linkUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Material(
                  color: V3.card2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => V3LottoLink.open(m.linkUrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                              m.linkLabel.isEmpty ? 'Read more' : m.linkLabel,
                              style: V3.inter(14,
                                  weight: FontWeight.w500, color: V3.green)),
                        ),
                        const Icon(Icons.chevron_right, color: V3.green),
                      ]),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: onDismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Got it',
                      style: V3.inter(16,
                          weight: FontWeight.w700, color: onAccent)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Text(position,
                  textAlign: TextAlign.center,
                  style: V3.inter(12.5, color: V3.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pinned important messages

/// An important message pinned at the top of the club screen until it ends,
/// even after "Got it" on the pop-up (Ken, 2026-11-26). Amber edge and
/// label, the sender, title and the whole message; a link opens.
class V3PinnedImportant extends StatelessWidget {
  const V3PinnedImportant(this.m, {super.key});
  final AppMessage m;

  @override
  Widget build(BuildContext context) {
    final accent = m.clubColour ?? V3.amber;
    return Material(
      color: V3.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: m.linkUrl.isEmpty ? null : () => V3LottoLink.open(m.linkUrl),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: V3.amber.withValues(alpha: 0.55)),
          ),
          // IntrinsicHeight: the stretched stripe needs a bounded height
          // inside the scrolling list.
          child: IntrinsicHeight(
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: V3.amberTint,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('IMPORTANT',
                              style: V3.inter(10.5,
                                  weight: FontWeight.w700,
                                  color: V3.amberText,
                                  letterSpacing: 0.6)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              [m.fromName, _when(m.startsAt)]
                                  .where((x) => x.isNotEmpty)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(12.5, color: V3.muted)),
                        ),
                      ]),
                      // The message's photo (Ken, 2026-11-27: it was missing).
                      if (m.imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(m.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: V3.bg)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(m.title,
                          style: V3.tight(17,
                              weight: FontWeight.w700, height: 1.2)),
                      if (m.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(m.body,
                            style: V3.inter(14,
                                color: const Color(0xFFD5D8DE), height: 1.45)),
                      ],
                      if (m.linkUrl.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(m.linkLabel.isEmpty ? 'Read more' : m.linkLabel,
                            style: V3.inter(14,
                                weight: FontWeight.w600, color: V3.green)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          )),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Club news cards

/// "Club news" on Home: a heading, then one card per live news item that
/// swipes sideways, the next card peeking in (Ken picked option C,
/// 2026-11-26, app-v3/news-banner/). Each card has a stripe in the club's
/// colour, the photo (or the crest on the club colour) on the left, and
/// the title with two lines of the message. A tap opens the News sheet.
/// Hidden when there is no news.
class V3NewsCards extends StatefulWidget {
  const V3NewsCards(
      {super.key,
      required this.news,
      required this.onTap,
      this.onItem,
      this.heading = true,
      this.stacked = false});
  final List<AppMessage> news;

  /// Opens the News tray (all stories).
  final VoidCallback onTap;

  /// A tap on one card (Ken, 2026-11-27: straight to its link, or that
  /// story on its own); falls back to [onTap].
  final void Function(AppMessage)? onItem;

  /// One card under another, no carousel: the club screen (Ken,
  /// 2026-11-26: news has its own screen now, so no need to swipe).
  final bool stacked;

  /// False for the compose preview: just the card.
  final bool heading;

  @override
  State<V3NewsCards> createState() => _V3NewsCardsState();
}

class _V3NewsCardsState extends State<V3NewsCards> {
  PageController? _pc;
  int _count = -1;
  int _page = 0;

  // Moves on by itself every 6 seconds and loops, so no item gets buried
  // (Ken, 2026-11-26). A touch pauses it for 10 seconds; off when the
  // phone asks for reduced motion.
  Timer? _timer;
  DateTime _pausedUntil = DateTime(0);

  PageController _controller() {
    final n = widget.news.length;
    if (_pc == null || n != _count) {
      _pc?.dispose();
      _count = n;
      _page = 0;
      _pc = PageController(viewportFraction: n > 1 ? 0.84 : 1);
    }
    return _pc!;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _advance());
  }

  void _advance() {
    final n = widget.news.length;
    final pc = _pc;
    if (!mounted || n < 2 || pc == null || !pc.hasClients) return;
    if (DateTime.now().isBefore(_pausedUntil)) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    pc.animateToPage((_page + 1) % n,
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  VoidCallback _tap(AppMessage m) => widget.onItem == null
      ? widget.onTap
      : () => widget.onItem!(m);

  void _pause() =>
      _pausedUntil = DateTime.now().add(const Duration(seconds: 10));

  @override
  void dispose() {
    _timer?.cancel();
    _pc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final news = widget.news;
    if (news.isEmpty) return const SizedBox.shrink();
    final club = news.every((n) => n.scope != 'all');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.heading)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
            child: Row(
              children: [
                // The heading and a clear "All news" button both open the
                // tray (Ken, 2026-11-27: the small "See all" was missed).
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    child: Text(club ? 'Club news' : 'News',
                        style: V3.tight(19, weight: FontWeight.w700)),
                  ),
                ),
                Material(
                    color: news.first.clubColour ?? V3.green,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: widget.onTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 6, 9, 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              'Read more',
                              style: V3.inter(13.5,
                                  weight: FontWeight.w700,
                                  color: (news.first.clubColour ?? V3.green)
                                              .computeLuminance() >
                                          0.5
                                      ? V3.bg
                                      : Colors.white)),
                          Icon(Icons.chevron_right,
                              size: 18,
                              color: (news.first.clubColour ?? V3.green)
                                          .computeLuminance() >
                                      0.5
                                  ? V3.bg
                                  : Colors.white),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Club screen: the newest two, the rest under All news (Ken,
        // 2026-11-27: "Where is the button to show all news?").
        if (widget.stacked)
          for (var i = 0; i < news.length && i < 2; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: SizedBox(
                  height: 132, child: _NewsCard(news[i], onTap: _tap(news[i]))),
            )
        else
          SizedBox(
            height: 132,
            child: Listener(
              onPointerDown: (_) => _pause(),
              child: PageView.builder(
                controller: _controller(),
                padEnds: false,
                itemCount: news.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(right: news.length > 1 ? 10 : 0),
                  child: _NewsCard(news[i], onTap: _tap(news[i])),
                ),
              ),
            ),
          ),
        if (news.length > 1 && !widget.stacked)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < news.length && k < 8; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: k == _page ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: k == _page ? V3.green : V3.barGrey,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard(this.m, {required this.onTap});
  final AppMessage m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = _when(m.startsAt).toUpperCase();
    final kicker =
        m.seen ? when : ['NEW', if (when.isNotEmpty) when].join(' · ');
    // Photo on the left only when the story has one; otherwise the text
    // takes the full width with a small crest top right, like the event
    // cards (Ken, 2026-11-26: a big crest on its own means nothing).
    final photo = m.imageUrl.isNotEmpty;
    return Material(
      color: V3.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: V3.line),
          ),
          child: Column(
            children: [
              // Stripe half primary, half secondary of the club that sent
              // it (Ken, 2026-11-27); CoachSmart green for CoachSmart news.
              SizedBox(
                height: 5,
                // stretch: a ColoredBox with no child is otherwise 0 high.
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (final c in m.stripeColours)
                    Expanded(child: ColoredBox(color: c)),
                ]),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photo)
                      SizedBox(
                        width: 104,
                        child: Image.network(m.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: V3.bg)),
                      ),
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(photo ? 13 : 15, 10, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (kicker.isNotEmpty || !photo)
                              Row(children: [
                                if (!m.seen)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                        color: V3.green,
                                        shape: BoxShape.circle),
                                  ),
                                Expanded(
                                  child: Text(kicker,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: V3.inter(11,
                                          weight: FontWeight.w700,
                                          color: m.seen ? V3.muted : V3.green,
                                          letterSpacing: 1.1)),
                                ),
                                if (!photo) ...[
                                  const SizedBox(width: 8),
                                  V3MessageBadge(m, size: 34),
                                ],
                              ]),
                            const SizedBox(height: 4),
                            Text(m.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: V3.tight(17,
                                    weight: FontWeight.w700, height: 1.2)),
                            if (m.body.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Expanded(
                                child: Text(m.body.replaceAll('\n', ' '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: V3.inter(13,
                                        color: V3.muted, height: 1.35)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fundraiser row

/// A club fundraiser (Christmas Draw, raffle, gear order) as one slim row
/// under Club news, like the old National Draw box: photo or crest, title,
/// "Fundraiser · price" in gold, and a green button that opens the club's
/// own page (Ken, 2026-11-26, app-v3/news-banner/fr-row-slim.png). Several
/// running at once swipe sideways. Hidden when there are none.
class V3FundraiserRow extends StatefulWidget {
  const V3FundraiserRow({super.key, required this.items, required this.onTap});
  final List<AppMessage> items;
  final void Function(AppMessage) onTap;

  @override
  State<V3FundraiserRow> createState() => _V3FundraiserRowState();
}

class _V3FundraiserRowState extends State<V3FundraiserRow> {
  int _page = 0;
  final _pc = PageController();

  // Two or more running: moves on every 7 seconds like Club news, so none
  // is hidden; a touch pauses it for 10 seconds.
  Timer? _timer;
  DateTime _pausedUntil = DateTime(0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      final n = widget.items.length;
      if (!mounted || n < 2 || !_pc.hasClients) return;
      if (DateTime.now().isBefore(_pausedUntil)) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      _pc.animateToPage((_page + 1) % n,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    if (_page >= items.length) _page = 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child: Listener(
              onPointerDown: (_) => _pausedUntil =
                  DateTime.now().add(const Duration(seconds: 10)),
              child: PageView.builder(
                controller: _pc,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _FundraiserTile(items[i],
                    onTap: () => widget.onTap(items[i])),
              ),
            ),
          ),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k < items.length && k < 8; k++)
                    Container(
                      width: k == _page ? 14 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: k == _page ? V3.amberText : V3.barGrey,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FundraiserTile extends StatelessWidget {
  const _FundraiserTile(this.m, {required this.onTap});
  final AppMessage m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = V3MessageBadge(m, size: 40);
    final thumb = m.imageUrl.isEmpty
        ? badge
        : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(m.imageUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => badge),
          );
    final label = m.linkLabel.isEmpty ? 'Buy tickets' : m.linkLabel;
    return Material(
      color: V3.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.amberLine),
          ),
          child: Row(
            children: [
              thumb,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(15, weight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(
                        m.priceLabel.isEmpty
                            ? 'Fundraiser'
                            : 'Fundraiser · ${m.priceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(12.5,
                            weight: FontWeight.w600, color: V3.amberText)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: V3.green,
                  foregroundColor: V3.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label,
                    style: V3.inter(14, weight: FontWeight.w600, color: V3.bg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every live news item, newest first; opening it marks them seen.
Future<void> showNewsSheet(
    BuildContext context, List<AppMessage> news, MessagesApi api) async {
  final unseen = [
    for (final n in news)
      if (!n.seen) n.id
  ];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: V3.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: V3.barGrey, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 14),
          Text('News', style: V3.tight(20, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final n in news) _NewsRow(n),
        ],
      ),
    ),
  );
  if (unseen.isEmpty) return;
  for (final n in news) {
    n.seen = true;
  }
  unawaited(api.markSeen(unseen).catchError((_) {}));
}

class _NewsRow extends StatelessWidget {
  const _NewsRow(this.m);
  final AppMessage m;

  @override
  // With a link, a tap anywhere on the item opens it (Ken, 2026-11-15).
  Widget build(BuildContext context) => InkWell(
        onTap: m.linkUrl.isEmpty ? null : () => V3LottoLink.open(m.linkUrl),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: V3.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              V3MessageBadge(m, size: 30),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        [m.fromName, _when(m.startsAt)]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: V3.inter(12, color: V3.muted)),
                    const SizedBox(height: 3),
                    Text(m.title, style: V3.inter(15, weight: FontWeight.w600)),
                    if (m.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(m.body,
                          style: V3.inter(13.5,
                              color: const Color(0xFFCFD2D8), height: 1.45)),
                    ],
                    if (m.linkUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          Flexible(
                            child: Text(
                                m.linkLabel.isEmpty ? 'Read more' : m.linkLabel,
                                style: V3.inter(13.5,
                                    weight: FontWeight.w600, color: V3.green)),
                          ),
                          const Icon(Icons.chevron_right,
                              color: V3.green, size: 18),
                        ]),
                      ),
                  ],
                ),
              ),
              if (!m.seen)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: 8),
                  decoration: const BoxDecoration(
                      color: V3.green, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      );
}
