#!/usr/bin/env python3
from pathlib import Path
import re

NL = '<a class="skip-link" href="#content">Ga naar inhoud</a>\n'
EN = '<a class="skip-link" href="#content">Skip to content</a>\n'

def is_en(path: Path) -> bool:
    return path.as_posix().startswith('en/')

def fix(path: Path, t: str) -> str:
    if path.name.startswith('google'):
        return t
    label = EN if is_en(path) else NL
    # Ensure <body>
    if re.search(r'<body\b', t, re.I) is None:
        if '</head>' in t:
            t = t.replace('</head>\n', '</head>\n<body>\n', 1)
            if '</body>' not in t.lower():
                t = t.replace('</html>', '</body>\n</html>') if '</html>' in t else t + '\n</body>\n'
        else:
            return t
    if 'class="skip-link"' not in t:
        m = re.search(r'<body[^>]*>\s*', t, re.I)
        if m:
            t = t[: m.end()] + label + t[m.end() :]
    if '<main' in t and 'id="content"' not in t:
        t = re.sub(r'<main(?![^>]*\bid=)', '<main id="content"', t, count=1)
    return t

n = 0
for f in Path('.').rglob('*.html'):
    if '.git' in f.parts:
        continue
    t = f.read_text()
    nt = fix(f, t)
    if nt != t:
        f.write_text(nt)
        n += 1
print('html updated', n)
