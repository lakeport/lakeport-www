#!/usr/bin/env python3
"""Post-build SSG HTML & discovery enhancer for lakeport.dev.

- Injects route-specific <title>, <meta name="description">, <link rel="canonical">,
  OpenGraph tags, brand favicons, apple-touch-icon, and WOFF2 font preloads
- Replaces inline module mount script + eager Wasm preload with CSP-clean /assets/entry.mjs
- Marks decorative <svg data-lp-svg> nodes aria-hidden="true" focusable="false" (Safari Audit)
- Marks horizontal scroll containers (.codePre, .tableWrap, .wb-code-body) tabindex="0" (Firefox/axe)
- Emits robots.txt, sitemap.xml, llms.txt, and .well-known/ard.json (Lighthouse 13 SEO + Agentic)
"""

from __future__ import annotations

import gzip
import html
import json
import re
from pathlib import Path

DIST_WEB = Path(__file__).resolve().parent.parent / "dist" / "web"
SITE_ORIGIN = "https://lakeport.dev"

DEFAULT_TITLE = "Lakeport: Build apps with agents, prove the rules that matter"
DEFAULT_DESC = (
    "Write JSX-style .lp views and CSS while your coding agent handles the state logic and proofs. "
    "Compiles to WebAssembly and native apps without requiring you to know Lean."
)

ROUTE_META: dict[str, tuple[str, str]] = {
    "/": (DEFAULT_TITLE, DEFAULT_DESC),
    "/why-lean": (
        "Why Lean under the hood? | Lakeport",
        "You do not need to learn Lean to use Lakeport. Write .lp templates and CSS, state your rules in plain English, and let the compiler verify your coding agent's work.",
    ),
    "/ecosystem": (
        "Packages & Live MDX Sandbox | Lakeport",
        "Official Lakeport packages for routing, browser effects, CSS modules, and pure WebAssembly MDX parsing with zero npm dependency sprawl.",
    ),
    "/showcase": (
        "Examples & Reference Apps | Lakeport",
        "Inspect real Lakeport apps including double-charge checkout protection, multi-version client API contracts, and this 17-route static site.",
    ),
    "/docs": (
        "Documentation Manual | Lakeport",
        "Twelve short chapters covering .lp templates, CSS styling, coding-agent workflows with lakeport mcp, routing, browser effects, and versioned client contracts.",
    ),
    "/docs/introduction": (
        "Introduction | Lakeport Docs",
        "What Lakeport is, how coding agents handle the Lean state logic for you, and when compiler-checked business rules pay off.",
    ),
    "/docs/installation": (
        "Installation | Lakeport Docs",
        "Install the Lakeport CLI, verify your toolchain with lakeport doctor, and connect lakeport mcp to Claude Code, Cursor, or Codex.",
    ),
    "/docs/getting-started": (
        "Your First App | Lakeport Docs",
        "Build a working Lakeport web app in ten minutes with JSX-style .lp views, plain CSS, and an agent-checked business rule.",
    ),
    "/docs/views-and-tsx": (
        "Views & .lp Syntax | Lakeport Docs",
        "Write familiar HTML-like .lp component templates with typed event handlers, conditional blocks, and SVG primitives.",
    ),
    "/docs/styling-and-lpcss": (
        "Styling & CSS | Lakeport Docs",
        "Style Lakeport apps with standard CSS custom properties, scoped package stylesheets, and compile-time class name checks.",
    ),
    "/docs/pure-core-and-proofs": (
        "State & Plain-English Rules | Lakeport Docs",
        "Keep state updates predictable and ask your coding agent to prove rules like no double-charges, with zero proof bytes in release bundles.",
    ),
    "/docs/routing-and-ssg": (
        "Routing & Static Pre-Rendering | Lakeport Docs",
        "Define URL routes that round-trip cleanly and pre-render instant static HTML pages that hydrate into WebAssembly.",
    ),
    "/docs/effects-and-offline": (
        "Effects, Fetch & Offline | Lakeport Docs",
        "Run HTTP requests, timers, clipboard actions, and storage through an explicit effect boundary that stays easy to test.",
    ),
    "/docs/versioned-contracts": (
        "Versioned Client Contracts | Lakeport Docs",
        "Keep active v1 and v2 API contracts in your client so backend releases in Go, TypeScript, Python, or Rust do not break open tabs.",
    ),
    "/docs/frontend-first-releases": (
        "Frontend-First Rollouts | Lakeport Docs",
        "Deploy multi-version Lakeport clients ahead of backend changes and enable new UI capabilities via server capability flags.",
    ),
    "/docs/reservoir-and-bundle-size": (
        "Packages & Bundle Size | Lakeport Docs",
        "Pull Lakeport packages from Reservoir and ship compact WebAssembly bundles without unused code.",
    ),
    "/docs/cli-and-mcp": (
        "CLI & MCP Reference | Lakeport Docs",
        "Command reference for lakeport dev, check, build, test, doctor, and the lakeport mcp server for AI coding agents.",
    ),
}

MOUNT_SCRIPT_RE = re.compile(
    r"\s*<script type=\"module\">\s*import \{ mount \} from '/runtime/boot\.mjs';.*?</script>",
    re.DOTALL,
)
SVG_OPEN_RE = re.compile(r"<svg\b(?![^>]*\baria-hidden=)(?![^>]*\baria-label=)")
SCROLLABLE_CLASS_RE = re.compile(
    r'<(pre|div)\b([^>]*\bclass="[^"]*(?:codePre|tableWrap|wb-code-body)[^"]*"[^>]*)>'
)


def route_for_html(html_path: Path) -> str:
    rel = html_path.relative_to(DIST_WEB)
    if rel == Path("index.html"):
        return "/"
    return "/" + "/".join(rel.parts[:-1])


def add_tabindex(match: re.Match[str]) -> str:
    tag, rest = match.group(1), match.group(2)
    if "tabindex=" in rest:
        return match.group(0)
    return f'<{tag}{rest} tabindex="0">'


def write_with_gz(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = text.encode("utf-8")
    path.write_bytes(data)
    gz_path = path.with_suffix(path.suffix + ".gz")
    if gz_path.exists():
        gz_path.write_bytes(gzip.compress(data, compresslevel=9))


def emit_discovery_files() -> None:
    robots = "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            "",
            f"Sitemap: {SITE_ORIGIN}/sitemap.xml",
            "",
        ]
    )
    (DIST_WEB / "robots.txt").write_text(robots, encoding="utf-8")

    urls = "\n".join(
        f"  <url><loc>{SITE_ORIGIN}{'' if r == '/' else r}</loc></url>"
        for r in ROUTE_META
    )
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{urls}\n"
        "</urlset>\n"
    )
    (DIST_WEB / "sitemap.xml").write_text(sitemap, encoding="utf-8")

    llms_lines = [
        "# Lakeport",
        "",
        "> Lakeport is a UI framework for building web and native apps with AI coding agents. Developers write JSX-style `.lp` views and standard `.css`, describe critical business rules in plain English, and let the Lean 4 compiler check the agent's state logic before shipping.",
        "",
        "## Overview",
        "",
        "- [Home](https://lakeport.dev/): Interactive $25 flaky-Wi-Fi checkout simulator showing how Lakeport catches retry bugs that unit tests miss.",
        "- [Why Lean?](https://lakeport.dev/why-lean): How regular web developers adopt Lakeport without learning theorem-prover syntax.",
        "- [Packages & Sandbox](https://lakeport.dev/ecosystem): Official Lakeport packages and a live WebAssembly Markdown/MDX sandbox.",
        "- [Examples](https://lakeport.dev/showcase): Reference apps for checkout idempotency, multi-version client contracts, and static sites.",
        "- [Documentation Index](https://lakeport.dev/docs): Full 12-chapter manual.",
        "",
        "## Documentation Chapters",
        "",
    ]
    for route, (title, desc) in ROUTE_META.items():
        if route.startswith("/docs/"):
            clean_title = title.replace(" | Lakeport Docs", "")
            llms_lines.append(f"- [{clean_title}]({SITE_ORIGIN}{route}): {desc}")
    llms_lines.append("")
    (DIST_WEB / "llms.txt").write_text("\n".join(llms_lines), encoding="utf-8")

    ard_manifest = {
        "entries": [
            {
                "identifier": "urn:air:lakeport.dev:docs:skills",
                "displayName": "Lakeport Documentation and Agent Guide",
                "description": (
                    "Documentation for .lp JSX-style views, CSS styling, plain-English business rules, "
                    "versioned client API contracts, and the lakeport mcp compiler tool server."
                ),
                "type": 'text/markdown; profile="urn:air:agent-skills"',
                "url": f"{SITE_ORIGIN}/llms.txt",
                "representativeQueries": [
                    "How do I build a Lakeport web app with an AI coding agent?",
                    "How does lakeport mcp give coding agents structured compiler feedback?",
                    "How do versioned client contracts keep older browser tabs working during backend deploys?",
                ],
            }
        ]
    }
    ard_path = DIST_WEB / ".well-known" / "ard.json"
    ard_path.parent.mkdir(parents=True, exist_ok=True)
    ard_path.write_text(json.dumps(ard_manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if not DIST_WEB.exists():
        return
    updated = 0
    for html_path in sorted(DIST_WEB.rglob("*.html")):
        raw = html_path.read_text(encoding="utf-8")
        route = route_for_html(html_path)
        title, desc = ROUTE_META.get(route, (DEFAULT_TITLE, DEFAULT_DESC))
        esc_title = html.escape(title, quote=True)
        esc_desc = html.escape(desc, quote=True)
        canonical = SITE_ORIGIN + ("/" if route == "/" else route)

        patched = re.sub(
            r"<title>.*?</title>",
            f"<title>{esc_title}</title>",
            raw,
            count=1,
            flags=re.DOTALL,
        )
        patched = re.sub(
            r'<meta name="description" content="[^"]*">',
            f'<meta name="description" content="{esc_desc}">',
            patched,
            count=1,
        )

        head_links = "\n".join(
            [
                f'  <link rel="canonical" href="{canonical}">',
                '  <link rel="icon" href="/assets/brand/favicon.svg" type="image/svg+xml">',
                '  <link rel="icon" href="/assets/brand/favicon.ico" sizes="32x32">',
                '  <link rel="apple-touch-icon" sizes="180x180" href="/assets/brand/apple-touch-icon.png">',
                '  <link rel="preload" href="/assets/fonts/Geist-Variable.woff2" as="font" type="font/woff2" crossorigin>',
                '  <link rel="preload" href="/assets/fonts/SchibstedGrotesk-Variable.woff2" as="font" type="font/woff2" crossorigin>',
                '  <meta property="og:type" content="website">',
                f'  <meta property="og:url" content="{canonical}">',
                f'  <meta property="og:title" content="{esc_title}">',
                f'  <meta property="og:description" content="{esc_desc}">',
                f'  <meta property="og:image" content="{SITE_ORIGIN}/assets/brand/og-default.png">',
                '  <meta name="twitter:card" content="summary_large_image">',
            ]
        )
        patched = patched.replace('  <link rel="icon" href="data:,">', head_links, 1)
        patched = patched.replace(
            '  <link rel="preload" href="/wasm/app_lp2.wasm" as="fetch" type="application/wasm" crossorigin>\n',
            "",
            1,
        )
        patched = patched.replace(
            '  <link rel="modulepreload" href="/runtime/boot.mjs">\n',
            "",
            1,
        )
        patched = MOUNT_SCRIPT_RE.sub(
            '\n  <script type="module" src="/assets/entry.mjs"></script>',
            patched,
            count=1,
        )
        patched = SVG_OPEN_RE.sub('<svg aria-hidden="true" focusable="false"', patched)
        patched = SCROLLABLE_CLASS_RE.sub(add_tabindex, patched)
        patched = patched.replace('class="docs-sidebar">', 'class="docs-sidebar" aria-label="Chapters">')
        patched = patched.replace('class="docs-toc">', 'class="docs-toc" aria-label="On this page">')

        write_with_gz(html_path, patched)
        updated += 1

    emit_discovery_files()
    print(f"[postbuild_head] Enhanced {updated} SSG HTML pages + robots.txt, sitemap.xml, llms.txt, ard.json.")


if __name__ == "__main__":
    main()
