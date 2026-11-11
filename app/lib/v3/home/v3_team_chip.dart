// One chip of the v3 Home team bar: "All", or a team with its club crest.
// Spec: docs/design/home-v3/HOME-V3-DESIGN.md §5.2.
import 'package:flutter/material.dart';

import '../v3_crest_image.dart';
import '../v3_theme.dart';

class V3TeamChip extends StatelessWidget {
  const V3TeamChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.crestUrl,
    this.clubName = '',
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? crestUrl; // null or empty: text-only chip
  final String clubName; // for the no-crest fallback initial

  @override
  Widget build(BuildContext context) {
    final hasCrest = crestUrl != null && crestUrl!.isNotEmpty;
    final muted = const Color(0xFFA1A1A2);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          padding: EdgeInsets.only(left: hasCrest ? 8 : 14, right: 14),
          decoration: BoxDecoration(
            color: selected ? V3.card2 : V3.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? V3.green.withValues(alpha: .6)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCrest) ...[
                ClipOval(
                  child: V3CrestImage(
                    crestUrl!,
                    size: 28,
                    fallback: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      color: const Color(0xFF252A34),
                      child: Text(
                        clubName.isEmpty ? '' : clubName[0].toUpperCase(),
                        style: V3.inter(
                          12,
                          weight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: V3.inter(
                  16,
                  weight: FontWeight.w600,
                  color: selected ? V3.text : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
