"""Give every font in a Flutter web build a content-hashed file name.

Flutter tree-shakes the icon fonts per build, so MaterialIcons-Regular.otf
holds different icons each time under the same name. Phones that cached an
older copy showed blank icons on new pages (Ken, 2026-11-11). Renaming each
font to name.<hash>.ext and rewriting FontManifest.json means a new build
always fetches the fonts it needs, while unchanged fonts stay cached.

Usage: python3 version_fonts.py <build/web dir>
"""
import hashlib
import json
import os
import sys

root = os.path.join(sys.argv[1], 'assets')
manifest_path = os.path.join(root, 'FontManifest.json')
with open(manifest_path) as f:
    manifest = json.load(f)

done = {}
for family in manifest:
    for font in family['fonts']:
        rel = font['asset']
        if rel not in done:
            path = os.path.join(root, rel)
            if not os.path.exists(path):
                done[rel] = rel
                continue
            with open(path, 'rb') as fh:
                digest = hashlib.sha256(fh.read()).hexdigest()[:10]
            base, ext = os.path.splitext(rel)
            new_rel = f'{base}.{digest}{ext}'
            os.rename(path, os.path.join(root, new_rel))
            done[rel] = new_rel
            print(f'{rel} -> {new_rel}')
        font['asset'] = done[rel]

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, separators=(',', ':'))
