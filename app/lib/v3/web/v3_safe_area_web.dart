import 'package:web/web.dart' as web;

web.HTMLDivElement? _probe;

/// The bottom safe-area inset in CSS pixels, from env(safe-area-inset-bottom).
double webBottomInset() {
  try {
    var p = _probe;
    if (p == null) {
      p = web.document.createElement('div') as web.HTMLDivElement;
      p.style.setProperty('position', 'fixed');
      p.style.setProperty('visibility', 'hidden');
      p.style.setProperty('pointer-events', 'none');
      p.style.setProperty('height', '0');
      p.style.setProperty('padding-bottom', 'env(safe-area-inset-bottom, 0px)');
      web.document.body?.append(p);
      _probe = p;
    }
    final v = web.window.getComputedStyle(p).paddingBottom;
    return double.tryParse(v.replaceAll('px', '')) ?? 0;
  } catch (_) {
    return 0;
  }
}
