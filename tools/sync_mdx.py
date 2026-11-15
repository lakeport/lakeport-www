#!/usr/bin/env python3
"""Sync `content/docs/*.mdx` files into `src/Docs/CatalogGen.lean` for pure-Lean Wasm compilation."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = ROOT / "content" / "docs"
OUT_FILE = ROOT / "src" / "Docs" / "CatalogGen.lean"


def lean_escape(s: str) -> str:
    out = ['"']
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append(f"\\x{ord(ch):02x}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def to_camel(slug: str) -> str:
    parts = slug.split("-")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def parse_frontmatter(raw: str) -> dict[str, str]:
    lines = raw.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" in line:
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip('"')
    return meta


def main() -> None:
    files = sorted(DOCS_DIR.glob("*.mdx"))
    entries = []
    for f in files:
        stem = re.sub(r"^\d+-", "", f.stem)
        ctor = to_camel(stem)
        raw = f.read_text(encoding="utf-8")
        meta = parse_frontmatter(raw)
        entries.append({
            "slug": stem,
            "ctor": ctor,
            "title": meta.get("title", stem),
            "summary": meta.get("summary", ""),
            "section": meta.get("section", "Guide"),
            "order": int(meta.get("order", "0")),
            "minutes": int(meta.get("readingMinutes", "5")),
            "updated": meta.get("updated", ""),
            "raw": raw,
        })

    lines = [
        "/-!",
        "# Generated MDX Documentation Catalog (`src/Docs/CatalogGen.lean`)",
        "",
        "Generated from `content/docs/*.mdx` by `tools/sync_mdx.py` so every `.mdx` page",
        "is parsed, highlighted, and rendered in pure Lean Wasm (and pre-rendered via SSG).",
        "-/",
        "namespace Site.Docs",
        "",
        "inductive DocSlug where",
    ]
    for e in entries:
        lines.append(f"  | {e['ctor']}")
    lines += [
        "  deriving DecidableEq, Repr, Inhabited",
        "",
        "namespace DocSlug",
        "",
        "def all : List DocSlug := [",
        "  " + ", ".join(f".{e['ctor']}" for e in entries),
        "]",
        "",
        "def slug : DocSlug -> String",
    ]
    for e in entries:
        lines.append(f"  | .{e['ctor']} => {lean_escape(e['slug'])}")
    lines += ["", "def parse? : String -> Option DocSlug"]
    for e in entries:
        lines.append(f"  | {lean_escape(e['slug'])} => some .{e['ctor']}")
    lines.append("  | _ => none")
    lines += ["", "def title : DocSlug -> String"]
    for e in entries:
        lines.append(f"  | .{e['ctor']} => {lean_escape(e['title'])}")
    lines += ["", "def summary : DocSlug -> String"]
    for e in entries:
        lines.append(f"  | .{e['ctor']} => {lean_escape(e['summary'])}")
    lines += ["", "def sectionName : DocSlug -> String"]
    for e in entries:
        lines.append(f"  | .{e['ctor']} => {lean_escape(e['section'])}")
    lines += ["", "def readingMinutes : DocSlug -> Nat"]
    for e in entries:
        lines.append(f"  | .{e['ctor']} => {e['minutes']}")
    lines += ["", "def rawMdx : DocSlug -> String"]
    for e in entries:
        lines.append(f"  | .{e['ctor']} => {lean_escape(e['raw'])}")
    lines += [
        "",
        "end DocSlug",
        "end Site.Docs",
        "",
    ]
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text("\n".join(lines), encoding="utf-8")
    print(f"Synced {len(entries)} MDX files -> {OUT_FILE}")


if __name__ == "__main__":
    main()
