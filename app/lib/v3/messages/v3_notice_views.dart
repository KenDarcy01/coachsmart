// Club notices open the way Club news posts do (Ken 2026-11-28): tapping one
// slides up that notice with its whole photo (never cropped) and the writing
// under it; "See all" opens a page of every notice, newest first.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../lotto/v3_lotto_link.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_messages_models.dart';

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

void _markSeen(List<AppMessage> news, MessagesApi api) {
  final unseen = [
    for (final n in news)
      if (!n.seen) n.id
  ];
  if (unseen.isEmpty) return;
  for (final n in news) {
    n.seen = true;
  }
  unawaited(api.markSeen(unseen).catchError((_) {}));
}

Widget _byline(AppMessage m, {double crest = 18}) => Row(children: [
      if (m.crest.isNotEmpty) ...[
        V3CrestImage(m.crest, size: crest),
        const SizedBox(width: 7),
      ],
      Flexible(
        child: Text(
            [m.fromName, _when(m.startsAt)]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V3.inter(12.5, color: V3.muted)),
      ),
    ]);

Widget _photo(String url) => Image.network(url,
    fit: BoxFit.fitWidth,
    width: double.infinity,
    errorBuilder: (_, __, ___) => const SizedBox.shrink());

List<Widget> _words(AppMessage m, {double title = 21}) => [
      Text(m.title,
          style: V3.tight(title, weight: FontWeight.w700, height: 1.2)),
      if (m.body.isNotEmpty) ...[
        const SizedBox(height: 7),
        Text(m.body, style: V3.inter(15, color: V3.text, height: 1.5)),
      ],
      if (m.linkUrl.isNotEmpty) ...[
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => V3LottoLink.open(m.linkUrl),
          style: FilledButton.styleFrom(
              backgroundColor: V3.green,
              foregroundColor: V3.bg,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: Text(m.linkLabel.isEmpty ? 'Read more' : m.linkLabel,
              style: V3.inter(15, weight: FontWeight.w600, color: V3.bg)),
        ),
      ],
    ];

/// "See all": every notice, newest first, in full.
Future<void> showAllNotices(
    BuildContext context, List<AppMessage> news, MessagesApi api,
    {AppMessage? start}) async {
  _markSeen(news, api);
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => V3NoticesPage(news: news, startId: start?.id)));
}

/// Tapping one notice opens this page at that notice (Ken 2026-11-28).
class V3NoticesPage extends StatefulWidget {
  const V3NoticesPage({super.key, required this.news, this.startId});
  final List<AppMessage> news;
  final int? startId;

  @override
  State<V3NoticesPage> createState() => _V3NoticesPageState();
}

class _V3NoticesPageState extends State<V3NoticesPage> {
  final _start = GlobalKey();

  @override
  void initState() {
    super.initState();
    final id = widget.startId;
    if (id == null || widget.news.isEmpty || widget.news.first.id == id) return;
    // Photos above it change height as they load: line it up again a few
    // times while they arrive.
    for (final ms in const [0, 300, 800, 1500]) {
      Future.delayed(Duration(milliseconds: ms), () {
        final c = _start.currentContext;
        if (mounted && c != null) Scrollable.ensureVisible(c);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final news = widget.news;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: V3.green,
        title:
            Text('Club notices', style: V3.tight(20, weight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        child: Column(children: [
          for (final m in news)
            Container(
              key: m.id == widget.startId ? _start : null,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: V3.card, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                    child: _byline(m, crest: 24),
                  ),
                  if (m.imageUrl.isNotEmpty) _photo(m.imageUrl),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _words(m, title: 18)),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}
