"""Builds the Féile 2027 explainer pages (parents and girls) from the templates here.

    python3 scripts/feile27-guides/build.py

{{i:name}} becomes an inline Font Awesome Free solid icon (icons.json, CC BY 4.0)
and {{v}} the cache-busting version. Output: clontarf-gaa/feile27/parents/, girls/, huddle/ and coaches/.
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'clontarf-gaa', 'feile27')
VERSION = '20261122g'
icons = json.load(open(os.path.join(HERE, 'icons.json')))

def icon(m):
    name = m.group(1)
    if name not in icons:
        sys.exit(f'missing icon {name}: add it to icons.json')
    box, path = icons[name]
    return f'<svg class="i" viewBox="{box}" aria-hidden="true"><path d="{path}"/></svg>'

for page in ('parents', 'girls', 'huddle', 'coaches'):
    html = open(os.path.join(HERE, f'{page}.tpl.html'), encoding='utf-8').read()
    html = re.sub(r'\{\{i:([a-z-]+)\}\}', icon, html).replace('{{v}}', VERSION)
    os.makedirs(os.path.join(OUT, page), exist_ok=True)
    open(os.path.join(OUT, page, 'index.html'), 'w', encoding='utf-8').write(html)
    print('built', page)
