# -*- coding: utf-8 -*-
"""Wrap the 5 refreshed template fragments in the SlidePreview shell and
render them to PNG for visual gate verification (no %-formatting)."""
import io
import os
import re
import subprocess
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
SRC = os.path.join(ROOT, 'assets', 'templates')
OUT = os.path.join(BASE, 'template_previews')
os.makedirs(OUT, exist_ok=True)

WRAP = """<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: file:; media-src data: file:; font-src data:; style-src 'unsafe-inline';">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: @@BG@@;
    color: #e2e8f0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .slide-canvas {
    width: 100%;
    height: 100%;
    padding: 3.5vw 4.5vw;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    overflow: hidden;
    position: relative;
  }
</style>
</head><body>
<div class="slide-canvas">
@@BODY@@
</div>
</body></html>
"""

EDGE = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
EDGE_64 = r'C:\Program Files\Microsoft\Edge\Application\msedge.exe'

PROFILE = os.path.join(OUT, '_edgeprofile')

# Mimic slide_preview: not a native scaling check, the canvas is 1280x720.
def main():
    edge = EDGE if os.path.exists(EDGE) else EDGE_64
    if not os.path.exists(edge):
        print('Edge not found; skip render')
        return 1
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for fname in sorted(os.listdir(SRC)):
        if not fname.endswith('.html'):
            continue
        slug = fname[:-5]
        if only and slug not in only:
            continue
        with io.open(os.path.join(SRC, fname), 'r', encoding='utf-8') as f:
            frag = f.read()
        m = re.search(r'data-bg-color=["\']([^"\']+)["\']', frag)
        bg = m.group(1) if m else '#1a1a2e'
        html = WRAP.replace('@@BG@@', bg).replace('@@BODY@@', frag)
        html_path = os.path.join(OUT, slug + '_preview.html')
        with io.open(html_path, 'w', encoding='utf-8') as f:
            f.write(html)
        png = os.path.join(OUT, slug + '_preview.png')
        subprocess.run([
            edge, '--headless', '--disable-gpu', '--hide-scrollbars',
            '--force-device-scale-factor=1',
            '--window-size=1280,720',
            '--user-data-dir=' + PROFILE,
            '--screenshot=' + png,
            'file:///' + html_path.replace('\\', '/'),
        ], check=False, capture_output=True, timeout=90)
        print('rendered', slug, '->', png)
    return 0

if __name__ == '__main__':
    sys.exit(main())
