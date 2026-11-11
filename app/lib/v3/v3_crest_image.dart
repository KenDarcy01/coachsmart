// Club crests for v3: cached on the phone (CachedNetworkImage) in a slot of
// fixed size, transparent while loading, so nothing jumps or pops in.
// Crests move to the public Supabase "crests" bucket as small PNGs with a
// long cache header (2026-11-11); the URLs come from clubs.crest.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class V3CrestImage extends StatelessWidget {
  const V3CrestImage(this.url, {super.key, required this.size, this.fallback});

  final String? url;
  final double size;

  /// Shown when there is no URL or the image fails; empty space otherwise.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final u = url ?? '';
    final empty = fallback ?? const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size,
      child: u.isEmpty
          ? empty
          // On the web, CachedNetworkImage draws through an HTML platform
          // view that goes black after leaving and coming back to a page
          // (Ken, 2026-11-11), so the web uses Image.network and the
          // browser cache (crests carry a one-year cache header).
          : kIsWeb
              ? Image.network(u,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  frameBuilder: (_, child, frame, sync) =>
                      sync || frame != null ? child : const SizedBox.shrink(),
                  errorBuilder: (_, __, ___) => empty)
              : CachedNetworkImage(
                  imageUrl: u,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 120),
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => empty,
                ),
    );
  }
}

/// Loads each crest once into memory so the tiles and cards draw at once.
final Set<String> _precached = {};

void precacheCrests(BuildContext context, Iterable<String?> urls) {
  for (final u in urls) {
    if (u == null || u.isEmpty || !_precached.add(u)) continue;
    final ImageProvider p =
        kIsWeb ? NetworkImage(u) : CachedNetworkImageProvider(u);
    precacheImage(p, context, onError: (_, __) => _precached.remove(u));
  }
}
