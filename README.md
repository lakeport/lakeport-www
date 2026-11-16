<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/logo/lakeport-logo-reverse.svg">
  <img src="assets/brand/logo/lakeport-logo.svg" alt="Lakeport" height="72">
</picture>

# lakeport-www

**Apps your agents can prove.**

Marketing website and 4-part engineering manual for **Lakeport** ([lakeport.dev](https://lakeport.dev)), built end to end in Lakeport (Lean 4, `.lp` TSX views, `.css` / `.lpcss` stylesheets, static site generation, and WebAssembly).

## Repository layout

- `assets/brand/` & `assets/fonts/`: Official Lakeport v1 brand assets (`logo/`, `icon/`, `social/`, `png/`, `tokens/lakeport.css`, `tokens/lakeport-tokens.json`, and SIL OFL WOFF2 variable fonts).
- `shared/` (`site-contract`): Shared leaf edge-contract package (`Version.v1` / `Version.v2`, `Capability`, fail-closed `Advertisement` parser, `WirePack` frames, dependent `Request`/`Response` families, and 16 theorems in `SiteContract/ContractLaws.lean`).
- `packages/lakeport-mdx/` (`lakeport-mdx`): Reusable pure-Lean MDX parser, Lean syntax highlighter, scoped `Mdx.css` module, `StyledView` renderer, and 6 theorems in `LakeportMdx/MdxLaws.lean`.
- `content/docs/*.mdx`: Source MDX files for all 12 documentation chapters (synced into `src/Docs/CatalogGen.lean` via `tools/sync_mdx.py`).
- `src/`:
  - `Routes.lean`: `SiteRoute` sum + `UrlCodec` + `LawfulUrlCodec` proof.
  - `Demo/Workbench.lean` & `Demo/WorkbenchLaws.lean`: Pure Lean checkout & capability-gate state machine, 4-stage rollout scrubber, dead-code explorer, and 15 kernel-checked theorems (`[proof-only, 0 B C]`).
  - `State.lean`, `Events.lean`, `SiteLaws.lean`: Application state, `MemoCell` MDX parse caching, UI event dispatch, and 5 navigation/cache theorems (`[proof-only, 0 B C]`).
  - `Brand.lp`, `Widgets.lp`, `Marketing.lp`, `DocsView.lp`, `App.lp`, `app.css`: Responsive light/dark editorial-technical UI built on the Lakeport v1 brand standard.
- `cloudflare/worker.mjs` & `wrangler.jsonc`: Cloudflare Worker host serving pre-rendered SSG assets, canonical `lakeport.dev` redirects, `/brand/tokens/lakeport.css`, and `GET /api/capabilities`.
- `tests/`: Negative contract exhaustiveness check (`check-negative-v3.py`) and headless WebAssembly smoke suite (`smoke-wasm.mjs`).

## Development & deployment

```sh
# Install Wrangler CLI devDependency
npm install

# Type-check .lp TSX, .css classes, .lean modules, and all *Laws.lean proofs
npm run check

# Build optimized WebAssembly + pre-render all 17 SSG HTML routes into dist/web/
npm run build

# Run negative contract check + headless Wasm interactive smoke tests
npm test

# Dry-run or publish release to lakeport.dev via Cloudflare Workers
npm run deploy:dry-run
npm run deploy
```

## License

Apache-2.0, ∎
