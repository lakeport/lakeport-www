#!/usr/bin/env python3
"""Inject Lakeport brand favicons, OpenGraph metadata, and WOFF2 preloads into SSG HTML."""

from __future__ import annotations

import gzip
from pathlib import Path

DIST_WEB = Path(__file__).resolve().parent.parent / "dist" / "web"

TARGET = '  <link rel="icon" href="data:,">'
REPLACEMENT = "\n".join(
    [
        '  <link rel="icon" href="/assets/brand/favicon.svg" type="image/svg+xml">',
        '  <link rel="icon" href="/assets/brand/favicon.ico" sizes="32x32">',
        '  <link rel="preload" href="/assets/fonts/Geist-Variable.woff2" as="font" type="font/woff2" crossorigin>',
        '  <link rel="preload" href="/assets/fonts/SchibstedGrotesk-Variable.woff2" as="font" type="font/woff2" crossorigin>',
        '  <meta property="og:type" content="website">',
        '  <meta property="og:title" content="Lakeport: Apps your agents can prove">',
        '  <meta property="og:description" content="WebAssembly and native apps in Lean 4 where edge contracts, offline retries, and domain invariants are checked by the Lean kernel.">',
        '  <meta property="og:image" content="https://lakeport.dev/assets/brand/og-default.png">',
        '  <meta name="twitter:card" content="summary_large_image">',
    ]
)


def main() -> None:
    if not DIST_WEB.exists():
        return
    updated = 0
    for html_path in sorted(DIST_WEB.rglob("*.html")):
        raw = html_path.read_text(encoding="utf-8")
        if TARGET not in raw:
            continue
        patched = raw.replace(TARGET, REPLACEMENT, 1)
        html_path.write_text(patched, encoding="utf-8")
        gz_path = html_path.with_suffix(html_path.suffix + ".gz")
        if gz_path.exists():
            gz_path.write_bytes(gzip.compress(patched.encode("utf-8"), compresslevel=9))
        updated += 1
    print(f"[postbuild_head] Updated brand head tags in {updated} HTML files.")


if __name__ == "__main__":
    main()
