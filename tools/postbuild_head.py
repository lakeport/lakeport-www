#!/usr/bin/env python3
"""Post-build SSG HTML & discovery enhancer for lakeport.dev.

- Injects route-specific <title>, <meta name="description">, <link rel="canonical">,
  OpenGraph tags, official brand favicons, apple-touch-icon, webmanifest, and WOFF2 preloads
- Replaces inline module mount script + eager Wasm preload with CSP-clean /assets/entry.mjs
- Marks decorative <svg data-lp-svg> and .waterline-reflection-text nodes aria-hidden="true"
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

DEFAULT_TITLE = "Lakeport: Apps your agents can prove"
DEFAULT_DESC = (
    "Write JSX-style .lp views and CSS while your coding agent writes the Lean state logic and proofs. "
    "Check local-first state, checkout, and API rules before they ship to WebAssembly."
)

ROUTE_META: dict[str, tuple[str, str]] = {
    "/": (DEFAULT_TITLE, DEFAULT_DESC),
    "/why-lean": (
        "Why Lean under the hood? | Lakeport",
        "You do not need to learn Lean to use Lakeport. Write .lp templates and CSS, state your rules in plain English, and let the compiler check your coding agent's work.",
    ),
    "/ecosystem": (
        "Packages & Live MDX Sandbox | Lakeport",
        "Official Lakeport packages for routing, browser effects, CSS modules, and pure WebAssembly MDX parsing with zero proof bytes shipped.",
    ),
    "/showcase": (
        "Examples & Evidence Ledger | Lakeport",
        "Inspect working Lakeport codebases including double-charge checkout protection, frontend JSON API contracts, and recorded platform evidence.",
    ),
    "/docs": (
        "Check it before it ships | Lakeport Docs",
        "Practical guides covering starter apps, local-first client patterns, frontend JSON schema unions, SDK modules, and how Lakeport's compiler and runtime are built.",
    ),
    "/docs/introduction": (
        "Introduction | Lakeport Docs",
        "Why Lakeport fits local-first and client-heavy apps, how compiled Lean WebAssembly works today, and what current platform evidence records.",
    ),
    "/docs/installation": (
        "Installation | Lakeport Docs",
        "Install the Lakeport CLI, verify your toolchain with lakeport doctor, and connect lakeport mcp to Claude Code, Cursor, or Codex.",
    ),
    "/docs/getting-started": (
        "Your First App | Lakeport Docs",
        "Build a local-first sync queue step by step, watch a buggy retry fail a Lean theorem, fix the reducer, and ship verified WebAssembly.",
    ),
    "/docs/pure-core-and-proofs": (
        "Client State & Proofs | Lakeport Docs",
        "Model local-first state machines in pure Lean, catch agent bugs with zero-byte theorems, and understand what proofs can and cannot check.",
    ),
    "/docs/versioned-contracts": (
        "Frontend Schema Unions | Lakeport Docs",
        "Decode active v1 and v2 JSON schemas in your frontend so Go, Node, Python, or Rust backend deploys do not break open tabs or Service Worker caches.",
    ),
    "/docs/frontend-first-releases": (
        "Frontend-First Rollouts | Lakeport Docs",
        "Ship dual-schema frontends ahead of backend changes, survive Service Worker cache overlap, and gate new write actions with optional capability headers.",
    ),
    "/docs/views-and-tsx": (
        "SDK Map, Views & .lp TSX | Lakeport Docs",
        "Discover Lakeport's built-in SDKs and plugins, write typed .lp views, and understand current button, hit-overlay, and gesture trade-offs.",
    ),
    "/docs/styling-and-lpcss": (
        "Styling & CSS | Lakeport Docs",
        "Style Lakeport apps with standard CSS custom properties, scoped package stylesheets, compile-time class checks, and native .lpcss bundles.",
    ),
    "/docs/routing-and-ssg": (
        "Routing & Static Pre-Rendering | Lakeport Docs",
        "Define URL routes with LawfulUrlCodec round-trip proofs, manage navigation state, and pre-render static HTML pages from WebAssembly.",
    ),
    "/docs/effects-and-offline": (
        "Effects, JSON & Offline Sync | Lakeport Docs",
        "Run HTTP, WebSocket, storage, JSON codecs, Service Worker caches, and idempotent offline outboxes across Lakeport's typed effect boundary.",
    ),
    "/docs/reservoir-and-bundle-size": (
        "Packages & Bundle Size | Lakeport Docs",
        "Pull Lakeport packages from Reservoir, erase proofs to zero bytes, and audit reachable declarations with .ilean dead-code checks.",
    ),
    "/docs/cli-and-mcp": (
        "CLI & MCP Reference | Lakeport Docs",
        "Command reference for lakeport dev, check, build, test, doctor, and the lakeport mcp server for AI coding agents.",
    ),
    "/docs/architecture-overview": (
        "Architecture Overview | Lakeport Docs",
        "Map of Lakeport's 17 packages, auto-imported Lean SDKs, frozen 4-node ViewApi kernel, LP2 C seam, and platform host shells.",
    ),
    "/docs/compiler-and-runtime": (
        "Compiler & LP2 Runtime | Lakeport Docs",
        "How Lakeport lowers .lp JSX with 1:1 line maps, rewrites 32-bit Wasm literals, runs dual-buffer LP2 dispatch, and pre-renders SSG HTML.",
    ),
    "/docs/contributor-guide": (
        "Code Quality & Contributor Guide | Lakeport Docs",
        "A candid engineering look at what is strong in Lakeport's codebase, where the rough edges and tech debt live, and where contributors can help.",
    ),
}

MOUNT_SCRIPT_RE = re.compile(
    r"\s*<script type=\"module\">\s*import \{ mount \} from '/runtime/boot\.mjs';.*?</script>",
    re.DOTALL,
)
SVG_OPEN_RE = re.compile(r"<svg\b(?![^>]*\baria-hidden=)(?![^>]*\baria-label=)")
SCROLLABLE_CLASS_RE = re.compile(
    r'<(pre|div)\b([^>]*\bclass="[^"]*(?:codePre|tableWrap|wb-code-body|sim-http-box)[^"]*"[^>]*)>'
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
        "> Apps your agents can prove. Lakeport is a client application framework in Lean 4 where developers write JSX-style `.lp` views and standard `.css`, state local-first sync, checkout, or API rules in plain English, and check agent-written state logic before shipping to WebAssembly.",
        "",
        "## Overview",
        "",
        "- [Home](https://lakeport.dev/): Interactive flaky-Wi-Fi checkout simulator showing how Lakeport catches retry bugs that unit tests miss.",
        "- [Why Lean?](https://lakeport.dev/why-lean): How regular web developers adopt Lakeport without learning theorem-prover syntax.",
        "- [Packages & Sandbox](https://lakeport.dev/ecosystem): Official Lakeport packages and a live WebAssembly Markdown/MDX sandbox.",
        "- [Examples](https://lakeport.dev/showcase): Working examples and recorded platform/proof evidence.",
        "- [Documentation Index](https://lakeport.dev/docs): Complete developer and contributor manual.",
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
                "displayName": "Lakeport Documentation and Contributor Guide",
                "description": (
                    "Apps your agents can prove: documentation for .lp JSX-style views, CSS styling, "
                    "local-first state rules, frontend JSON schema unions, lakeport mcp, and compiler architecture."
                ),
                "type": 'text/markdown; profile="urn:air:agent-skills"',
                "url": f"{SITE_ORIGIN}/llms.txt",
                "representativeQueries": [
                    "How do I build a local-first Lakeport web app with an AI coding agent?",
                    "How do frontend JSON schema unions keep open tabs and Service Worker caches working during backend deploys?",
                    "How is Lakeport architected across its Lean compiler, LP2 C ABI, and host runtimes?",
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
                '  <link rel="icon" href="/assets/brand/icon/favicon.svg" type="image/svg+xml">',
                '  <link rel="icon" href="/assets/brand/icon/favicon.ico" sizes="32x32">',
                '  <link rel="apple-touch-icon" sizes="180x180" href="/assets/brand/icon/apple-touch-icon.png">',
                '  <link rel="manifest" href="/assets/brand/site.webmanifest">',
                '  <meta name="theme-color" content="#F8F6F3" media="(prefers-color-scheme: light)">',
                '  <meta name="theme-color" content="#00181B" media="(prefers-color-scheme: dark)">',
                '  <link rel="preload" href="/assets/fonts/Geist-Variable.woff2" as="font" type="font/woff2" crossorigin>',
                '  <link rel="preload" href="/assets/fonts/SchibstedGrotesk-Variable.woff2" as="font" type="font/woff2" crossorigin>',
                *( ['  <link rel="preload" href="/assets/fonts/JetBrainsMono-Variable.woff2" as="font" type="font/woff2" crossorigin>'] if route.startswith('/docs/') else [] ),
                '  <meta property="og:type" content="website">',
                f'  <meta property="og:url" content="{canonical}">',
                f'  <meta property="og:title" content="{esc_title}">',
                f'  <meta property="og:description" content="{esc_desc}">',
                f'  <meta property="og:image" content="{SITE_ORIGIN}/assets/brand/social/og-default.png">',
                '  <meta property="og:image:width" content="1200">',
                '  <meta property="og:image:height" content="630">',
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
        patched = patched.replace(
            'class="waterline-reflection-text">',
            'class="waterline-reflection-text" aria-hidden="true">',
        )
        patched = patched.replace('class="docs-sidebar">', 'class="docs-sidebar" aria-label="Chapters">')
        patched = patched.replace('class="docs-toc">', 'class="docs-toc" aria-label="On this page">')

        write_with_gz(html_path, patched)
        updated += 1

    emit_discovery_files()
    print(f"[postbuild_head] Enhanced {updated} SSG HTML pages + robots.txt, sitemap.xml, llms.txt, ard.json.")


if __name__ == "__main__":
    main()
