// Small helpers for the v3 car pool pages.

/// "4 seats · 2 free" / "4 seats · full".
String seatsLine(int total, int free) =>
    '$total ${total == 1 ? 'seat' : 'seats'} · ${free > 0 ? '$free free' : 'full'}';

/// Initials for a full name ("Aimee Morris" → "AM").
String nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final s = parts.map((p) => p[0]).take(2).join().toUpperCase();
  return s.isEmpty ? '?' : s;
}

/// The status line under the seat tiles.
String poolStatusLine(int free, int reserved) {
  if (free <= 0) return 'This car pool is full.';
  if (reserved <= 0) return 'No seats reserved yet.';
  return 'In this car pool';
}
