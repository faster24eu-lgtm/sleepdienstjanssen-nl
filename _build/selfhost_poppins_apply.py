#!/usr/bin/env python3
"""Replace Google Fonts link triad with local Poppins preloads in all HTML."""
from pathlib import Path
import re

NEW = (
    '  <link rel="preload" href="/assets/fonts/poppins-400-latin.woff2" as="font" type="font/woff2" crossorigin>\n'
    '  <link rel="preload" href="/assets/fonts/poppins-800-latin.woff2" as="font" type="font/woff2" crossorigin>\n'
    '  <link rel="preload" href="/assets/fonts/poppins-800i-latin.woff2" as="font" type="font/woff2" crossorigin>'
)
pat = re.compile(
    r'[ \t]*<link rel="preconnect" href="https://fonts\.googleapis\.com">\s*'
    r'[ \t]*<link rel="preconnect" href="https://fonts\.gstatic\.com" crossorigin>\s*'
    r'[ \t]*<link href="https://fonts\.googleapis\.com/css2\?family=Poppins:[^"]+" rel="stylesheet">',
    re.S,
)
n = 0
for f in Path('.').rglob('*.html'):
    t = f.read_text()
    if 'fonts.googleapis.com' not in t:
        continue
    nt, c = pat.subn(NEW, t, count=1)
    if c:
        f.write_text(nt)
        n += 1
        continue
    # line-based fallback
    lines = t.splitlines(True)
    out = []
    i = 0
    changed = False
    while i < len(lines):
        if 'fonts.googleapis.com' in lines[i] and 'preconnect' in lines[i]:
            block = ''.join(lines[i:i + 3])
            if 'fonts.gstatic.com' in block and 'Poppins' in block:
                out.append(NEW + '\n')
                i += 3
                changed = True
                continue
        if 'fonts.googleapis.com' in lines[i] and 'Poppins' in lines[i]:
            out.append(NEW + '\n')
            i += 1
            changed = True
            continue
        if 'fonts.gstatic.com' in lines[i] and 'preconnect' in lines[i]:
            i += 1
            changed = True
            continue
        out.append(lines[i])
        i += 1
    if changed:
        f.write_text(''.join(out))
        n += 1
print('html updated', n)
