// Full-screen picture with pinch / double-tap zoom and Share, used for
// pathway pictures (Player Pathways, Sample Sessions) and game diagrams.
// Port of the web page's image viewer screen ("Pinch to zoom · Double-tap to
// zoom in · Hold to share").
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../v3_theme.dart';

/// Shares a picture as a file, falling back to its link (web
/// shareCurrentImage()). Returns a message to show, or null.
Future<String?> shareImageUrl(String url, String title, {Rect? origin}) async {
  if (url.isEmpty) return null;
  try {
    final r = await http.get(Uri.parse(url));
    if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
      final type = r.headers['content-type'] ?? '';
      final ext = type.contains('png') ? 'png' : 'jpg';
      final safe = title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      final name = '${safe.isEmpty ? 'image' : safe}.$ext';
      await SharePlus.instance.share(ShareParams(files: [
        XFile.fromData(r.bodyBytes,
            mimeType: type.isEmpty ? 'image/$ext' : type, name: name)
      ], fileNameOverrides: [
        name
      ], title: title, sharePositionOrigin: origin));
      return null;
    }
  } catch (_) {
    // Fall through to sharing the link.
  }
  try {
    await SharePlus.instance.share(ShareParams(
        uri: Uri.tryParse(url), title: title, sharePositionOrigin: origin));
    return null;
  } catch (_) {
    return 'Could not share';
  }
}

/// Full-screen picture page.
class V3ImageViewerPage extends StatefulWidget {
  const V3ImageViewerPage(
      {super.key,
      required this.imageUrl,
      required this.title,
      this.subtitle = ''});

  final String imageUrl;
  final String title;
  final String subtitle;

  @override
  State<V3ImageViewerPage> createState() => _V3ImageViewerPageState();
}

class _V3ImageViewerPageState extends State<V3ImageViewerPage> {
  final _zoom = TransformationController();
  final _shareKey = GlobalKey();
  TapDownDetails? _tap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final msg = await shareImageUrl(widget.imageUrl, widget.title,
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: V3.inter(14, color: V3.bg)),
          backgroundColor: V3.amber));
    }
  }

  void _doubleTap() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.05) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final p = _tap?.localPosition ?? Offset.zero;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.imageUrl.isNotEmpty;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(widget.title,
            overflow: TextOverflow.ellipsis, style: V3.tight(17)),
        actions: [
          IconButton(
              key: _shareKey,
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share, color: V3.green),
              onPressed: _share),
        ],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        if (has) ...[
          GestureDetector(
            onDoubleTapDown: (d) => _tap = d,
            onDoubleTap: _doubleTap,
            onLongPress: _share,
            child: InteractiveViewer(
              transformationController: _zoom,
              minScale: 1,
              maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.fitWidth,
                width: double.infinity,
                placeholder: (_, __) => const SizedBox(
                    height: 240,
                    child: Center(
                        child: CircularProgressIndicator(color: V3.green))),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Pinch to zoom · Double-tap to zoom in · Hold to share',
                textAlign: TextAlign.center,
                style: V3.inter(13, color: V3.muted)),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title,
                style: V3.tight(21, weight: FontWeight.w700, height: 1.3)),
            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.subtitle,
                  style: V3.inter(16, color: V3.muted, height: 1.6)),
            ],
          ]),
        ),
      ]),
    );
  }
}
