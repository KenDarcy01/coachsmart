// "Follow a club" from the menu (Ken, 2026-11-26): the club code box, the
// club card, Follow. No search: the code comes from the club's poster,
// website or link. A team code here points to Join a team instead.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../join_team/v3_join_team_page.dart';
import '../tracking/v3_track.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_follow_api.dart';

class V3FollowClubPage extends StatefulWidget {
  const V3FollowClubPage({super.key, this.api = const FollowApi()});

  final FollowApi api;

  @override
  State<V3FollowClubPage> createState() => _V3FollowClubPageState();
}

class _V3FollowClubPageState extends State<V3FollowClubPage> {
  final _code = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  bool _looking = false;
  bool _busy = false;
  CodeLookup _found = CodeLookup.none;
  String? _error;

  @override
  void initState() {
    super.initState();
    V3Track.screen('V3FollowClub');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _changed(String raw) {
    final up = raw.toUpperCase();
    if (up != raw) {
      _code.value = _code.value.copyWith(
          text: up, selection: TextSelection.collapsed(offset: up.length));
    }
    final code = normaliseCode(up);
    _debounce?.cancel();
    final seq = ++_seq;
    setState(() {
      _error = null;
      _found = CodeLookup.none;
      _looking = code.length >= 3;
    });
    if (code.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      CodeLookup r;
      try {
        r = await widget.api.lookup(code);
      } catch (_) {
        r = CodeLookup.none;
      }
      if (!mounted || seq != _seq) return;
      setState(() {
        _looking = false;
        _found = r;
      });
    });
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = normaliseCode(d?.text ?? '');
    if (!mounted) return;
    if (t.length < 3 || t.length > 20) {
      setState(() => _error = 'Nothing to paste. Type the code instead.');
      return;
    }
    _code.text = t;
    _changed(t);
  }

  Future<void> _follow() async {
    final c = _found.club;
    if (c == null) return;
    if (c.following) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = true);
    FollowedClub? r;
    try {
      r = await widget.api.follow(normaliseCode(_code.text));
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      setState(() => _error = 'Something went wrong. Please try again.');
      return;
    }
    V3Track.event('club_followed', {'club_id': r.clubId, 'from': 'menu'});
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final club = _found.club;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 36),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            Text('Follow a club', style: V3.tight(20, weight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text("Enter the club code from the club's poster, website or link.",
                style: V3.inter(16, color: V3.muted, height: 1.45)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('club-code'),
              controller: _code,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 20,
              onChanged: _changed,
              cursorColor: V3.green,
              style: V3
                  .tight(26, weight: FontWeight.w700)
                  .copyWith(letterSpacing: 3),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Club code',
                hintStyle: V3.inter(17, color: const Color(0xFF6F737C)),
                filled: true,
                fillColor: V3.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: V3.line, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: V3.green, width: 1.5)),
              ),
            ),
            if (_code.text.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: Text('Paste code',
                        style: V3.inter(15,
                            weight: FontWeight.w600, color: V3.green)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: V3.green,
                        minimumSize: const Size(44, 44),
                        side: const BorderSide(color: V3.nextLine, width: 1.5),
                        shape: const StadiumBorder()),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_looking)
              Text('Looking up code…', style: V3.inter(15, color: V3.muted))
            else if (club != null)
              _clubCard(club)
            else if (_found.kind == CodeKind.team)
              _teamCodeNote()
            else if (normaliseCode(_code.text).length >= 3)
              Text("That code isn't recognised. Check it with the club.",
                  style: V3.inter(15, color: V3.muted)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: V3.inter(15, color: V3.redText)),
              ),
            if (club != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _follow,
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: V3.bg))
                      : Text(
                          club.following
                              ? 'Already following'
                              : 'Follow ${club.name}',
                          style: V3.inter(17,
                              weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _clubCard(FollowedClub c) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: V3.nextLine, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            V3CrestImage(c.crest,
                size: 52,
                fallback: const Icon(Icons.shield_outlined,
                    color: V3.green, size: 40)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: V3.tight(20, weight: FontWeight.w700)),
                    Text(c.line, style: V3.inter(15, color: V3.muted)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text("You'll see the club's news, matches and results on Home.",
              style: V3.inter(15, height: 1.45)),
        ]),
      );

  Widget _teamCodeNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("That's a team code for ${_found.teamName}.",
              style: V3.inter(16, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Team codes join a team, and the coach approves.',
              style: V3.inter(15, color: V3.muted)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    settings: const RouteSettings(name: 'V3JoinTeamPage'),
                    builder: (_) => const V3JoinTeamPage())),
            style: TextButton.styleFrom(
                foregroundColor: V3.green, minimumSize: const Size(44, 44)),
            child: Text('Join a team instead',
                style: V3.inter(16, weight: FontWeight.w700, color: V3.green)),
          ),
        ]),
      );
}
