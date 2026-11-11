// v3 Score keeper: the on-phone reader for what the coach said, a straight
// port of webviews/cs-score-voice.js. It runs with no AI and no network, so
// voice still works with no signal.
//
//   parseVoice("Point Ciarán and a wide for Ballymun", ctx) -> items:
//     score  typeId, side 'us', memberId, heard 'ciaran', count 1
//     score  typeId, side 'opp', memberId null, count 1
//
// An item can also carry side null (nobody named), fromId (what a score
// came from: "point Murrough free"), ask (candidates for a name it wasn't
// sure of) or be a sub (onId, offId, onHeard, offHeard). For a stat that
// isn't a score, side is whose ball it is now, so "free against Luke" is
// side 'opp' with memberId Luke (he gave it away).
import 'dart:math' as math;

class VoiceType {
  const VoiceType(
      {required this.id,
      required this.name,
      this.abbr = '',
      this.value,
      this.source = false});
  final int id;
  final String name;
  final String abbr;
  final int? value;
  final bool source;
}

class VoicePlayer {
  const VoicePlayer(
      {required this.memberId,
      required this.firstName,
      required this.lastName,
      this.number});
  final int memberId;
  final String firstName;
  final String lastName;
  final int? number;
}

class VoiceCtx {
  const VoiceCtx(
      {required this.types,
      required this.usName,
      required this.oppName,
      required this.players,
      this.aliases = const {}});
  final List<VoiceType> types;
  final String usName;
  final String oppName;
  final List<VoicePlayer> players;

  /// Heard name -> member id, saved per team on this phone.
  final Map<String, int> aliases;
}

class VoiceItem {
  VoiceItem.score({
    required this.typeId,
    required this.typeName,
    required this.count,
    required this.side,
    this.memberId,
    this.heard = '',
    this.ask,
    this.fromId,
    this.against = false,
  })  : kind = 'score',
        onId = null,
        offId = null,
        onHeard = '',
        offHeard = '';
  VoiceItem.sub({this.onId, this.offId, this.onHeard = '', this.offHeard = ''})
      : kind = 'sub',
        typeId = 0,
        typeName = '',
        count = 0,
        side = null,
        memberId = null,
        heard = '',
        ask = null,
        fromId = null,
        against = false;

  final String kind; // 'score' | 'sub'
  final int typeId;
  final String typeName;
  final int count;
  final String? side; // 'us' | 'opp' | null
  final int? memberId;
  final String heard;
  final List<int>? ask;
  final int? fromId;
  final bool against;
  final int? onId;
  final int? offId;
  final String onHeard;
  final String offHeard;
}

class VoiceResult {
  VoiceResult(this.items, this.unknown, {this.transcript = ''});
  final List<VoiceItem> items;
  final List<String> unknown;
  final String transcript;
}

// ------------------------------------------------------------------ text

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y', 'ç': 'c', 'ñ': 'n',
};

String _deaccent(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

/// Lower case, no accents or apostrophes, only letters, digits, + and
/// single spaces.
String voiceNorm(String? s) => _deaccent((s ?? '').toLowerCase())
    .replaceAll(RegExp('[’\']'), '')
    .replaceAll(RegExp(r'[^a-z0-9+ ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _nums = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
  'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
  'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fourty': 40,
};

/// Speech engines write numbers either way; settle on digits.
String _numberWords(String s) {
  s = s.replaceAllMapped(
      RegExp(
          r'\b(twenty|thirty|forty|fourty) (one|two|three|four|five|six|seven|eight|nine)\b'),
      (m) => '${_nums[m[1]]! + _nums[m[2]]!}');
  return s.replaceAllMapped(
      RegExp(
          r'\b(zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fourty)\b'),
      (m) => '${_nums[m[1]]}');
}

// Irish names the speech engine tends to spell the English way. Both sides
// are folded to the same key before comparing.
final _sounds = <(RegExp, String)>[
  (RegExp(r'^(kieran|keiran|kieron|ciaran|kiran)$'), 'ciaran'),
  (RegExp(r'^(shawn|shaun|sean|shane)$'), 'sean'),
  (RegExp(r'^(owen|eoin|eoghan)$'), 'eoin'),
  (RegExp(r'^(osheen|oisin|ocean)$'), 'oisin'),
  (RegExp(r'^(neil|neal|niall|nile)$'), 'niall'),
  (RegExp(r'^(keen|kian|cian|keane)$'), 'cian'),
  (RegExp(r'^(dara|darragh|darra)$'), 'darragh'),
  (RegExp(r'^(cahal|cathal|kahal)$'), 'cathal'),
  (RegExp(r'^(fin|finn|fionn)$'), 'fionn'),
  (RegExp(r'^(tige|teig|tadhg|tague)$'), 'tadhg'),
  (RegExp(r'^(aidan|aodhan|aiden|aedan)$'), 'aidan'),
  (RegExp(r'^(padraig|pauric|porick|padraic)$'), 'padraig'),
  (RegExp(r'^(connor|conor|conner)$'), 'conor'),
  (RegExp(r'^(rory|ruairi|ruari|rorie)$'), 'rory'),
  (RegExp(r'^(cillian|killian|kilian|cilian)$'), 'cillian'),
  (RegExp(r'^(shay|se)$'), 'shay'),
  (RegExp(r'^(senan|shenan)$'), 'senan'),
  (RegExp(r'^(fiachra|feeakra)$'), 'fiachra'),
  (RegExp(r'^(caoimhe|keeva|keva)$'), 'caoimhe'),
  (RegExp(r'^(aoife|eefa|eva)$'), 'aoife'),
  (RegExp(r'^(niamh|neve|neeve)$'), 'niamh'),
  (RegExp(r'^(siobhan|shivaun|chevonne)$'), 'siobhan'),
  (RegExp(r'^(saoirse|seersha|sorcha)$'), 'saoirse'),
  (RegExp(r'^(roisin|rosheen)$'), 'roisin'),
  (RegExp(r'^(grainne|grania)$'), 'grainne'),
  (RegExp(r'^(sadhbh|sive|sieve)$'), 'sadhbh'),
  (RegExp(r'^(clodagh|cloda)$'), 'clodagh'),
  (RegExp(r'^(ailbhe|alva)$'), 'ailbhe'),
];

String voiceSoundKey(String w) {
  for (final (re, k) in _sounds) {
    if (re.hasMatch(w)) return k;
  }
  // Rough fold for everything else: soft letters and doubled letters
  return w
      .replaceAll('ph', 'f')
      .replaceAll('k', 'c')
      .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!)
      .replaceAll('h', '');
}

int _lev(String a, String b) {
  if (a == b) return 0;
  final m = a.length, n = b.length;
  if (m == 0 || n == 0) return m == 0 ? n : m;
  var prev = List<int>.generate(n + 1, (j) => j);
  for (var i = 1; i <= m; i++) {
    final cur = List<int>.filled(n + 1, 0)..[0] = i;
    for (var j = 1; j <= n; j++) {
      cur[j] = math.min(math.min(prev[j] + 1, cur[j - 1] + 1),
          prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[n];
}

double voiceSim(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  if (voiceSoundKey(a) == voiceSoundKey(b)) return 0.95;
  return 1 -
      _lev(voiceSoundKey(a), voiceSoundKey(b)) / math.max(a.length, b.length);
}

/// Words for each kind of stat, built from the team's own types.
List<String> _typeWords(VoiceType t) {
  final n = voiceNorm(t.name), a = voiceNorm(t.abbr);
  final out = <String>{n};
  void add(List<String> w) => out.addAll(w);
  if (a.length > 1 && !RegExp(r'^(p|g|w)$').hasMatch(a)) out.add(a);
  if (t.value == 3 || n.contains('goal'))
    add(['goal', 'goals', 'gold', 'goel']);
  if (t.value == 2 || RegExp(r'2 ?point|two ?point').hasMatch(n)) {
    add([
      '2pointer',
      '2 pointer',
      '2 pointers',
      'two pointer',
      'to pointer',
      'too pointer',
      'double'
    ]);
  }
  if (t.value == 1 || n == 'point') {
    add(['point', 'points', 'pointe', 'over the bar']);
  }
  if (n.contains('wide')) add(['wide', 'wides', 'white', 'wired']);
  if (n.contains('short')) add(['short', 'dropped short', 'shorts']);
  if (n.startsWith('free')) add(['free', 'frees', 'free kick']);
  if (RegExp(r'45|forty').hasMatch(n)) add(['45', '45s', 'forty five']);
  if (RegExp(r'65|sixty').hasMatch(n)) add(['65', '65s', 'sixty five']);
  if (n.contains('penal')) add(['penalty', 'penalties', 'pen']);
  if (n.contains('mark')) add(['mark', 'marks']);
  if (n.contains('turn')) {
    add([
      'turnover',
      'turnovers',
      'turn over',
      'lost it',
      'lost the ball',
      'lost possession'
    ]);
  }
  if (RegExp(r'throw ?in').hasMatch(n)) {
    add(['throw in', 'throwin', 'throw ins', 'throw ball in']);
  }
  // The puck-out is hurling's kick-out: either word finds whichever the
  // team has.
  if (RegExp(r'kick ?out|puck ?out').hasMatch(n)) {
    add([
      'kickout',
      'kick out',
      'kickouts',
      'kick outs',
      'puckout',
      'puck out',
      'puckouts',
      'puck outs'
    ]);
  }
  final list = out.map(voiceNorm).where((w) => w.isNotEmpty).toList();
  list.sort((x, y) => y.length - x.length);
  return list;
}

final _filler = ('a an the for to by from scored score scores got get gets '
        'was is it its that this and then by our number no num nr shirt '
        'jersey player who from with of on in at')
    .split(' ')
    .toSet();
const _usWords = {'us', 'we', 'ours', 'ourselves', 'home'};
const _oppWords = {
  'them',
  'they',
  'theirs',
  'opposition',
  'opponents',
  'opponent',
  'away',
  'other',
  'oppo',
  'opp'
};
// "free against Luke", "Luke conceded a free", "Luke gave away a free"
const _againstSrc =
    r'\b(against|conceded|concedes|concede|gave away|gives away|give away|gave|given away)\b';
final _against = RegExp(_againstSrc);

List<String> voiceTeamWords(String name) {
  const stop = {
    'gaa', 'gfc', 'hc', 'club', 'cumann', 'camogie', 'lgfa', 'ladies', //
    'football', 'hurling', 'st', 'saint', 'naomh', 'clg', 'the', 'and',
  };
  return voiceNorm(name)
      .split(' ')
      .where((w) =>
          w.length > 2 &&
          !stop.contains(w) &&
          !RegExp(r'^u\d+$').hasMatch(w) &&
          !RegExp(r'^\d+$').hasMatch(w))
      .toList();
}

class _P {
  _P(this.id, this.number, this.first, this.last, this.full);
  final int id;
  final int? number;
  final String first;
  final String last;
  final String full;
}

/// {id} for a sure match, {ask} when unsure.
class _Match {
  _Match({this.id, this.ask = const []});
  final int? id;
  final List<int> ask;
}

class _Matcher {
  _Matcher(VoiceCtx ctx) {
    for (final p in ctx.players) {
      final f = voiceNorm(p.firstName).split(' ');
      players.add(_P(
          p.memberId,
          p.number,
          f.isEmpty ? '' : f.first,
          voiceNorm(p.lastName)
              .replaceFirstMapped(RegExp(r'^(o|mc|mac) '), (m) => m[1]!),
          voiceNorm('${p.firstName} ${p.lastName}')));
    }
    ctx.aliases.forEach((k, v) => aliases[voiceNorm(k)] = v);
  }

  final players = <_P>[];
  final aliases = <String, int>{};

  _Match? byName(List<String> words) {
    final heard = words.join(' ');
    if (heard.isEmpty) return null;
    final al = aliases[heard];
    if (al != null && players.any((p) => p.id == al)) return _Match(id: al);
    final scored = <(_P, double)>[];
    for (final p in players) {
      double s;
      if (words.length >= 2) {
        s = math.max(
            voiceSim(words[0], p.first) * 0.5 +
                voiceSim(
                        words.sublist(1).join(''), p.last.replaceAll(' ', '')) *
                    0.5,
            voiceSim(heard.replaceAll(' ', ''), p.full.replaceAll(' ', '')));
      } else {
        final w = words[0];
        s = [
          voiceSim(w, p.first),
          voiceSim(w, p.last.replaceFirst(RegExp(r'^(o|mc|mac)'), '')) * 0.92,
          voiceSim(w, p.last.replaceAll(' ', '')) * 0.92,
        ].reduce(math.max);
      }
      if (s >= 0.55) scored.add((p, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    if (scored.isEmpty) return _Match();
    final top = scored.first;
    final tied = scored.where((x) => x.$2 >= top.$2 - 0.001).length;
    final next = scored.length > 1 ? scored[1] : null;
    final clear =
        next == null || (top.$2 == 1 ? next.$2 < 1 : top.$2 - next.$2 >= 0.1);
    if (top.$2 >= 0.85 && tied == 1 && clear) return _Match(id: top.$1.id);
    return _Match(ask: [for (final x in scored.take(3)) x.$1.id]);
  }

  _Match byNumber(int n) {
    for (final p in players) {
      if (p.number == n) return _Match(id: p.id);
    }
    return _Match();
  }
}

class _Who {
  _Who(this.side, this.memberId, this.heard, [this.ask]);
  final String? side;
  final int? memberId;
  final String heard;
  final List<int>? ask;
}

final _digits = RegExp(r'^\d+$');

/// Who is a clause about?
_Who _who(List<String> words, VoiceCtx ctx, _Matcher m) {
  final usW = voiceTeamWords(ctx.usName).toSet();
  final oppW = voiceTeamWords(ctx.oppName).toSet();
  String? side;
  final rest = <String>[];
  for (final w in words) {
    if (_usWords.contains(w) || usW.contains(w)) {
      side ??= 'us';
    } else if (_oppWords.contains(w) || oppW.contains(w)) {
      side ??= 'opp';
    } else if (!_filler.contains(w)) {
      rest.add(w);
    }
  }
  if (side == 'opp') return _Who(side, null, '');
  final num = rest.where((w) => _digits.hasMatch(w)).firstOrNull;
  if (num != null) {
    final r = m.byNumber(int.parse(num));
    return _Who('us', r.id, '#$num', r.id != null ? null : r.ask);
  }
  if (rest.isEmpty) return _Who(side, null, '');
  final r = m.byName(rest);
  if (r != null && r.id != null) return _Who('us', r.id, rest.join(' '));
  return _Who(side ?? 'us', null, rest.join(' '), r?.ask ?? const []);
}

VoiceItem? _parseSub(List<String> words, _Matcher m) {
  // "sub 17 for 11", "17 on for 11", "11 off 17 on", "Cillian on for Ciarán"
  final txt = words
      .join(' ')
      .replaceAll(
          RegExp(
              r'\b(sub|subs|substitute|substitution|change|coming|goes|going|replaces|replacing|in)\b'),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  String onPart, offPart;
  RegExpMatch? mm;
  if ((mm = RegExp(r'^(.+?) off (?:and )?(.+?) on$').firstMatch(txt)) != null) {
    offPart = mm![1]!;
    onPart = mm[2]!;
  } else if ((mm = RegExp(r'^(.+?) on (?:and )?(.+?) off$').firstMatch(txt)) !=
      null) {
    onPart = mm![1]!;
    offPart = mm[2]!;
  } else if ((mm =
          RegExp(r'^(.+?) (?:on )?for (.+?)(?: off)?$').firstMatch(txt)) !=
      null) {
    onPart = mm![1]!.replaceFirst(RegExp(r' on$'), '');
    offPart = mm[2]!;
  } else {
    return null;
  }
  (int?, String) pick(String part) {
    final ws =
        part.split(' ').where((w) => w.isNotEmpty && !_filler.contains(w));
    final num = ws.where((w) => _digits.hasMatch(w)).firstOrNull;
    if (num != null) return (m.byNumber(int.parse(num)).id, '#$num');
    return (m.byName(ws.toList())?.id, ws.join(' '));
  }

  final on = pick(onPart), off = pick(offPart);
  return VoiceItem.sub(
      onId: on.$1, onHeard: on.$2, offId: off.$1, offHeard: off.$2);
}

/// Reads what was said into score, stat and sub entries.
VoiceResult parseVoice(String text, VoiceCtx ctx) {
  final m = _Matcher(ctx);
  var s = _numberWords(voiceNorm(text));
  s = s
      .replaceAll(RegExp(r'\b(2|two|to|too) ?-?pointers?\b'), '2pointer')
      .replaceAllMapped(RegExp(r'\b(off|on) and\b'), (x) => x[1]!);
  // Split into separate calls: "goal Ken and a wide for them, then point Seán"
  final clauses = s
      .split(RegExp(r'\b(?:and then|then|and also|also|plus|and|next)\b|,'))
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty);
  final types = [for (final t in ctx.types) (t, _typeWords(t))];
  final items = <VoiceItem>[];
  final unknown = <String>[];
  for (final c in clauses) {
    var words = c.split(' ');
    if (RegExp(r'\b(sub|subs|substitute|substitution)\b').hasMatch(c) ||
        RegExp(r'\bon for\b').hasMatch(c) ||
        RegExp(r'\boff\b.*\bon\b|\bon\b.*\boff\b').hasMatch(c)) {
      final sub = _parseSub(words, m);
      if (sub != null) {
        items.add(sub);
        continue;
      }
    }
    // Find the stat (longest phrase wins). A score named with a source
    // ("point Murrough free") is one score from a free, not two stats.
    final hit = <int, (VoiceType, String)>{};
    for (final (t, tw) in types) {
      for (final w in tw) {
        final re = RegExp('(^| )${RegExp.escape(w)}( |\$)');
        final prev = hit[t.id];
        if (re.hasMatch(c) && (prev == null || w.length > prev.$2.length)) {
          hit[t.id] = (t, w);
        }
      }
    }
    final hits = hit.values.toList()..sort((a, b) => b.$2.length - a.$2.length);
    final scoreHit = hits.where((h) => (h.$1.value ?? 0) > 0).firstOrNull;
    final srcHit = scoreHit == null
        ? null
        : hits.where((h) => h != scoreHit && h.$1.source).firstOrNull;
    final found = scoreHit ?? hits.firstOrNull;
    if (found == null) {
      unknown.add(c);
      continue;
    }
    var restTxt = c
        .replaceFirst(RegExp('(^| )${RegExp.escape(found.$2)}( |\$)'), ' ')
        .trim();
    if (srcHit != null) {
      restTxt = restTxt
          .replaceFirst(
              RegExp(
                  '(^| )(off |from )?(a )?${RegExp.escape(srcHit.$2)}( |\$)'),
              ' ')
          .trim();
    }
    // Who gave it away: "free against Luke", "Luke lost it"
    final scoring = (found.$1.value ?? 0) > 0;
    var against = false;
    if (!scoring &&
        (_against.hasMatch(restTxt) || found.$2.startsWith('lost '))) {
      against = true;
      restTxt = restTxt
          .replaceAll(_against, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    words = restTxt.isEmpty ? <String>[] : restTxt.split(' ');
    // "two wides for them": a small count in front of the type
    var count = 1;
    final cw = c.split(' ');
    final idx = cw.indexOf(found.$2.split(' ').first);
    final before = idx > 0 ? cw[idx - 1] : null;
    if (before != null &&
        RegExp(r'^[2-5]$').hasMatch(before) &&
        found.$2.endsWith('s')) {
      count = int.parse(before);
      final bi = words.indexOf(before);
      if (bi >= 0) {
        words.removeAt(bi);
      } else if (words.isNotEmpty) {
        words.removeLast(); // as Array.splice(-1, 1) does
      }
    }
    final w = _who(words, ctx, m);
    // Against us (a player or our team named) = their ball; against them = ours
    var side = w.side;
    if (against) side = w.side == 'opp' ? 'us' : 'opp';
    final ourPlayer = side == 'us' || (against && w.side != 'opp');
    items.add(VoiceItem.score(
      typeId: found.$1.id,
      typeName: found.$1.name,
      count: count,
      against: against,
      side: side,
      memberId: ourPlayer ? w.memberId : null,
      heard: ourPlayer ? w.heard : '',
      ask: ourPlayer ? w.ask : null,
      fromId: srcHit?.$1.id,
    ));
  }
  return VoiceResult(items, unknown);
}
