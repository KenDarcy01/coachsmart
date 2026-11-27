// Club news from the club's own social posts (Ken 2026-11-27, thread
// "Feed Clontarf socials into Club news"). The server mirrors whatever the
// club's website shows in its social feed (Clontarf: the Instagram block
// on clontarfgaa.com) into club_social_posts every 30 minutes; this reads
// get_club_social_posts. Big photo cards that swipe sideways; a tap opens
// the whole post here (never a link out to Instagram, Ken). Admin-written
// news is now "Club notices" (V3NewsCards).

import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '/v3/tracking/v3_track.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';

class ClubSocialPost {
  ClubSocialPost.fromJson(Map j)
      : id = j['id'] is num ? (j['id'] as num).toInt() : 0,
        clubId = j['club_id'] is num ? (j['club_id'] as num).toInt() : 0,
        clubName = '${j['club_name'] ?? ''}',
        crest = '${j['crest'] ?? ''}',
        imageUrl = '${j['image_url'] ?? ''}',
        caption = '${j['caption'] ?? ''}'.trim(),
        postedAt = DateTime.tryParse('${j['posted_at'] ?? ''}')?.toLocal();

  final int id, clubId;
  final String clubName, crest, imageUrl, caption;
  final DateTime? postedAt;

  /// "3h ago", "Yesterday", "Tue", "21 Nov".
  String get when {
    final t = postedAt;
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return d.inMinutes <= 1 ? 'Just now' : '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    // Calendar days, so 47 hours ago is not "Yesterday".
    final now = DateTime.now();
    final days0 = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    if (days0 <= 1) return 'Yesterday';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (days0 < 7) return days[t.weekday - 1];
    return '${t.day} ${months[t.month - 1]}';
  }

  static Future<List<ClubSocialPost>> load(List<int> clubIds) async {
    if (clubIds.isEmpty) return const [];
    final r = await SupaFlow.client.rpc('get_club_social_posts',
        params: {'p_club_ids': clubIds, 'p_limit': 20});
    return [
      if (r is List)
        for (final p in r.whereType<Map>()) ClubSocialPost.fromJson(p)
    ].where((p) => p.imageUrl.isNotEmpty).toList();
  }
}

/// "Club news" on the club screen: heading with "See all ›", then photo
/// cards that swipe sideways with the next one peeking in. Hidden when
/// there are no posts.
class V3ClubSocialNews extends StatefulWidget {
  const V3ClubSocialNews({super.key, required this.posts});
  final List<ClubSocialPost> posts;

  @override
  State<V3ClubSocialNews> createState() => _V3ClubSocialNewsState();
}

class _V3ClubSocialNewsState extends State<V3ClubSocialNews> {
  final _pc = PageController(viewportFraction: 0.82);
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _seeAll() {
    V3Track.event('club_social_all', {});
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3ClubSocialPage(posts: widget.posts)));
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts.take(10).toList();
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 6, 8),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _seeAll,
                child: Text('Club news',
                    style: V3.tight(19, weight: FontWeight.w700)),
              ),
            ),
            TextButton(
              onPressed: _seeAll,
              style: TextButton.styleFrom(
                  foregroundColor: V3.green,
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: Text('See all ›',
                  style: V3.inter(14.5,
                      weight: FontWeight.w600, color: V3.green)),
            ),
          ]),
        ),
        SizedBox(
          height: 316,
          child: PageView.builder(
            controller: _pc,
            padEnds: false,
            itemCount: posts.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(right: posts.length > 1 ? 10 : 0),
              child: _SocialCard(posts[i]),
            ),
          ),
        ),
        if (posts.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 9, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < posts.length; k++)
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

// Posts are often posters with the headline at the top: crop from the top.
Widget _photo(String url, {BoxFit fit = BoxFit.cover}) => Image.network(url,
    fit: fit,
    alignment: Alignment.topCenter,
    width: double.infinity,
    errorBuilder: (_, __, ___) => const ColoredBox(color: V3.bg));

Widget _byline(ClubSocialPost p, {double crest = 18}) => Row(children: [
      if (p.crest.isNotEmpty) ...[
        V3CrestImage(p.crest, size: crest),
        const SizedBox(width: 7),
      ],
      Flexible(
        child: Text(
            [p.clubName, p.when].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V3.inter(12.5, color: V3.muted)),
      ),
    ]);

class _SocialCard extends StatelessWidget {
  const _SocialCard(this.p);
  final ClubSocialPost p;

  @override
  Widget build(BuildContext context) => Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showClubSocialPost(context, p),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: V3.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 204, child: _photo(p.imageUrl)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(p.caption.replaceAll('\n', ' '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(14,
                                  color: const Color(0xFFE3E6EA),
                                  height: 1.38)),
                        ),
                        _byline(p),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The whole post: photo and full caption.
Future<void> showClubSocialPost(BuildContext context, ClubSocialPost p) {
  V3Track.event('club_social_open', {'club_id': p.clubId});
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: V3.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: V3.barGrey, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _byline(p, crest: 26),
          ),
          _photo(p.imageUrl, fit: BoxFit.fitWidth),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(p.caption,
                style: V3.inter(15, color: V3.text, height: 1.5)),
          ),
        ],
      ),
    ),
  );
}

/// "See all": every post, newest first, captions in full.
class V3ClubSocialPage extends StatelessWidget {
  const V3ClubSocialPage({super.key, required this.posts});
  final List<ClubSocialPost> posts;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(
          backgroundColor: V3.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: V3.green,
          title: Text('Club news', style: V3.tight(20, weight: FontWeight.w700)),
          centerTitle: false,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
          itemCount: posts.length,
          itemBuilder: (_, i) {
            final p = posts[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: V3.card, borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                    child: _byline(p, crest: 24),
                  ),
                  _photo(p.imageUrl, fit: BoxFit.fitWidth),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 14),
                    child: Text(p.caption,
                        style: V3.inter(14.5, height: 1.45)),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
