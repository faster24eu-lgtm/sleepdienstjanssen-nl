#!/usr/bin/env python3
"""Apply verified a11y HTML fixes sitewide."""
from pathlib import Path
import re

def fix(t: str) -> str:
    t = re.sub(r'(<a class="logo"[^>]*)\s+aria-label="[^"]*"', r'\1', t)
    repls = [
        ('<h4>Werkgebied</h4>', '<h2 class="foot-h">Werkgebied</h2>'),
        ('<h4>Diensten</h4>', '<h2 class="foot-h">Diensten</h2>'),
        ('<h4>Contact</h4>', '<h2 class="foot-h">Contact</h2>'),
        ('<h4>Service area</h4>', '<h2 class="foot-h">Service area</h2>'),
        ('<h4>Services</h4>', '<h2 class="foot-h">Services</h2>'),
    ]
    for a, b in repls:
        t = t.replace(a, b)
    return t

n = 0
for f in Path('.').rglob('*.html'):
    t = f.read_text()
    nt = fix(t)
    if nt != t:
        f.write_text(nt)
        n += 1
print('html updated', n)
