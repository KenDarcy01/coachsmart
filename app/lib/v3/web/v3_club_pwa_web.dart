import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Points the page's title, apple-touch-icon, home-screen name, theme colour
/// and manifest at the club, so adding it to the home screen opens this
/// page full screen under the club's name and crest.
void setClubPwa(
    {required String name, required String icon, required String colour}) {
  try {
    final doc = web.document;
    doc.title = name;
    void meta(String n, String content) {
      var m = doc.querySelector('meta[name="$n"]') as web.HTMLMetaElement?;
      if (m == null) {
        m = doc.createElement('meta') as web.HTMLMetaElement..name = n;
        doc.head?.append(m);
      }
      m.content = content;
    }

    meta('apple-mobile-web-app-title', name);
    meta('application-name', name);
    meta('apple-mobile-web-app-capable', 'yes');
    meta('mobile-web-app-capable', 'yes');
    meta('theme-color', colour);
    if (icon.isNotEmpty) {
      for (final rel in ['apple-touch-icon', 'icon']) {
        var l = doc.querySelector('link[rel="$rel"]') as web.HTMLLinkElement?;
        if (l == null) {
          l = doc.createElement('link') as web.HTMLLinkElement..rel = rel;
          doc.head?.append(l);
        }
        l.href = icon;
      }
    }
    // A manifest for this page (Android "Install app"), opening this URL.
    final here = web.window.location.href;
    final manifest = jsonEncode({
      'name': name,
      'short_name': name,
      'start_url': here,
      'scope': web.window.location.origin + '/',
      'display': 'standalone',
      'background_color': colour,
      'theme_color': colour,
      'icons': [
        if (icon.isNotEmpty)
          {'src': icon, 'sizes': '512x512', 'purpose': 'any'},
      ],
    });
    final blob = web.Blob(
        [manifest.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
    final url = web.URL.createObjectURL(blob);
    var l = doc.querySelector('link[rel="manifest"]') as web.HTMLLinkElement?;
    if (l == null) {
      l = doc.createElement('link') as web.HTMLLinkElement..rel = 'manifest';
      doc.head?.append(l);
    }
    l.href = url;
  } catch (_) {
    // Branding the tab is a nicety; never break the page over it.
  }
}
