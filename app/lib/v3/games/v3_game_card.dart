// A game row for any games list (Resources, Favourites, Session plan,
// Add a resource): a coloured dot for the kind, the name, type / skill /
// club tags and an optional heart. Port of _gameRowHtml() in
// webviews/games-resource-v2.html.
import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_game_models.dart';

/// Purple used for drills (web #a78bfa) and blue for videos / club (#60a5fa).
const Color kDrillPurple = Color(0xFFA78BFA);
const Color kVideoBlue = Color(0xFF60A5FA);
const Color kHeartRed = Color(0xFFEF4444);

/// The accent colour of a kind: green game, amber warmup, purple drill,
/// blue video, grey skill.
Color gameKindColor(GameKind k) => switch (k) {
      GameKind.game => V3.green,
      GameKind.warmup => V3.amber,
      GameKind.drill => kDrillPurple,
      GameKind.video => kVideoBlue,
      GameKind.skill => V3.muted,
    };

/// A small rounded tag. [color] tints text, border and background.
class V3GameTag extends StatelessWidget {
  const V3GameTag(this.label,
      {super.key, this.color = V3.muted, this.size = 13});
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label,
          style: V3.inter(size, weight: FontWeight.w600, color: color)),
    );
  }
}

/// The heart button: red and filled when [on]. At least 48px to tap.
class V3HeartButton extends StatelessWidget {
  const V3HeartButton({super.key, required this.on, required this.onPressed});
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: on ? 'Remove from favourites' : 'Add to favourites',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: onPressed,
      icon: Icon(on ? Icons.favorite : Icons.favorite_border,
          color: on ? kHeartRed : V3.muted, size: 26),
    );
  }
}

/// One game in a list.
///
/// * [onTap] opens it (usually [V3GameDetailPage]).
/// * [onFavourite] null hides the heart (Skills rows have none).
/// * [clubName] labels club-owned games (web: the "club" tag, 'Club' when
///   the name is unknown).
/// * [trailing] replaces the heart, e.g. an Add button on Session plan.
class V3GameCard extends StatelessWidget {
  const V3GameCard({
    super.key,
    required this.game,
    this.onTap,
    this.isFavourite = false,
    this.onFavourite,
    this.clubName = '',
    this.trailing,
  });

  final V3Game game;
  final VoidCallback? onTap;
  final bool isFavourite;
  final VoidCallback? onFavourite;
  final String clubName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final kind = game.kind;
    final kc = gameKindColor(kind);
    final typeColor = kind == GameKind.game ? V3.muted : kc;
    return Material(
      color: V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: V3.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: kc, shape: BoxShape.circle)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.name,
                          style: V3.inter(17,
                              weight: FontWeight.w600, height: 1.25)),
                      if (game.types.isNotEmpty ||
                          game.skills.isNotEmpty ||
                          game.clubId != null) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final t in game.types)
                            V3GameTag(t, color: typeColor),
                          for (final s in game.skills.take(2)) V3GameTag(s),
                          if (game.clubId != null)
                            V3GameTag(clubName.isNotEmpty ? clubName : 'Club',
                                color: kVideoBlue),
                        ]),
                      ],
                    ]),
              ),
              if (trailing != null)
                trailing!
              else if (onFavourite != null)
                V3HeartButton(on: isFavourite, onPressed: onFavourite!)
              else
                const SizedBox(width: 10),
            ]),
          ),
        ),
      ),
    );
  }
}
