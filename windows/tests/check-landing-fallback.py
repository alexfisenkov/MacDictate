#!/usr/bin/env python3
"""Read actual HTML anchors without executing JavaScript or fetching metadata."""
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import urlparse


class InstallerLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == 'a' and attrs.get('data-windows-asset') == 'installer':
            self.links.append(attrs.get('href', ''))


root = Path(__file__).resolve().parents[2]
html = InstallerLinks()
html.feed((root / 'web-landing/index.html').read_text())
assert len(html.links) >= 2, 'Expected hero and download-section installer links'
for href in html.links:
    url = urlparse(href)
    assert url.scheme == 'https' and url.netloc == 'github.com' and re.fullmatch(
        r'/alexfisenkov/MacDictate/releases/download/v\d+\.\d+\.\d+/MacDictate_Windows_v\d+\.\d+\.\d+_x64\.exe', url.path
    ), f'Windows installer must remain a pinned EXE when JavaScript is disabled: {href}'
assert len(set(html.links)) == 1, 'All HTML installer fallbacks must use the same pinned EXE'
print(f'PASS {len(html.links)} actual HTML pinned installer fallbacks (JavaScript not executed)')
