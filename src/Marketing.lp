import LakeportMdx
import State
import Events
import Widgets
set_option synthInstance.maxSize 4096
/-!
# `Site.Marketing` — Homepage, Why Lean, Ecosystem (with Live MDX Sandbox) & Showcase

Clean, scannable marketing pages combining React Native's calm clarity with
Lakeport's live Lean 4 WebAssembly verification demos.
-/
namespace Site.Marketing
open LakeportStyle LakeportMdx Site Site.Widgets

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

private def clickableCard (title body linkLabel href : String) (iconShapes : List V) : V :=
  <div class="feature-card" data-clickable={true}>
    <button class="hit-overlay" onClick={Ev.nav href}>{title}</button>
    <div class="card-icon">{svg "18" iconShapes}</div>
    <h3 class="card-title">{title}</h3>
    <p class="card-body">{body}</p>
    <span class="card-link-hint">{linkLabel}</span>
  </div>

private def staticCard (title body : String) (iconShapes : List V) : V :=
  <div class="feature-card" data-clickable={false}>
    <div class="card-icon">{svg "18" iconShapes}</div>
    <h3 class="card-title">{title}</h3>
    <p class="card-body">{body}</p>
  </div>

/-! ## 1. Homepage (`/`) -/

def homePage (s : AppState) : V :=
  let cliCmd := "lakeport check && lakeport build web --release"
  let cliCopied := s.copiedKey == "hero-cli"
  <div>
    <section class="hero-section">
      <div class="container">
        <div class="hero-grid">
          <div class="eyebrow">
            <span>Lean 4 + .lp TSX + Native & WebAssembly</span>
          </div>
          <h1 class="hero-title">Let your agents move fast. Let the Lean kernel guard the rules</h1>
          <p class="hero-lead">
            Lakeport builds cross-platform web, desktop, and mobile apps from a single pure Lean 4 codebase. Express edge contracts, capability gates, and balance invariants once, verify them at compile time, and ship compact WebAssembly and native views with zero runtime proof overhead.
          </p>
          <div class="cta-row">
            {primaryBtn "Get started in 10 minutes" (Ev.nav "/docs/getting-started")}
            {secondaryBtn "Read the docs" (Ev.nav "/docs/introduction")}
            <div class="cli-pill">
              <span class="cli-prompt">$</span>
              <span>{cliCmd}</span>
              <button class="cli-copy" data-copied={cliCopied} onClick={Ev.copy "hero-cli" cliCmd}>
                {if cliCopied then "Copied" else "Copy"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Interactive Lean 4 WebAssembly workbench</span>
          <h2 class="section-title">Watch what happens when an agent ships a subtle retry bug</h2>
          <p class="section-desc">
            Unit tests pass twenty happy-path cases and miss the socket drop that double-charges a customer. Switch between three agent patches below: everything on the right is running live inside this page's compiled Lean WebAssembly module.
          </p>
        </div>
        {workbenchView s.workbench}
      </div>
    </section>

    <section class="section-subtle">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Deployment discipline</span>
          <h2 class="section-title">Versioned union contracts, frontend released first</h2>
          <p class="section-desc">
            Old browser tabs, mobile binaries, and rolling backend pods always overlap in production. Put an exhaustive Version sum in a shared leaf package and ship the capability-gated client before turning backend features on.
          </p>
        </div>
        {rolloutTimelineView s.rolloutStage}
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Architecture</span>
          <h2 class="section-title">Familiar component ergonomics, real platform primitives</h2>
          <p class="section-desc">
            You write typed JSX (.lp) and standard CSS (.css). Lakeport checks every class name and attribute at compile time, pre-renders static HTML on the web, and drives native platform widgets without a JavaScript bridge or Skia canvas clone.
          </p>
        </div>
        <div class="cards-3">
          {staticCard
            "Pure Lean 4 domain core"
            "State, URL codecs, wire serializers, and reducers are ordinary pure functions. Prove conservation or round-trip laws right next to your code; Lean erases every proof before C/Wasm emission."
            Icon.shield}
          {staticCard
            "Compile-time TSX & CSS"
            "Write readable .lp components and scoped import_css modules. Unknown classes, unkeyed dynamic lists, and missing accessible button labels fail lakeport check with exact source lines."
            Icon.code}
          {staticCard
            "Web SSG + native shells"
            "Web builds pre-render static HTML from your compiled Wasm and hydrate at commit 0 with zero node creations. Desktop and mobile shells link the same Lean C core against GTK4, AppKit, UIKit, Direct2D, and Android Views."
            Icon.layers}
        </div>
      </div>
    </section>

    <section class="section-subtle">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Where Lakeport fits</span>
          <h2 class="section-title">How Lakeport compares across the hybrid stack</h2>
          <p class="section-desc">
            Different tools optimize for different trade-offs. Choose React Native when you want npm's huge component catalog; choose Lakeport when correctness across retries, wire versions, and agent-authored patches matters most.
          </p>
        </div>
        <div class="comp-wrap">
          <div class="comp-table">
            <div class="comp-head-row">
              <div class="comp-cell-label">Dimension</div>
              <div class="comp-cell-hi">Lakeport (Lean 4)</div>
              <div class="comp-cell">React Native / Expo</div>
              <div class="comp-cell">Rust Wasm / NSH-style native</div>
              <div class="comp-cell">Elm</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Domain invariants</div>
              <div class="comp-cell-hi">Kernel-checked theorems on actual executed reducer (0 B runtime cost)</div>
              <div class="comp-cell">TypeScript shapes + runtime tests</div>
              <div class="comp-cell">Ownership & borrow types + runtime tests</div>
              <div class="comp-cell">Pure Elm types + property tests</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Edge wire evolution</div>
              <div class="comp-cell-hi">Dependent Request/Response indexed by Version; wildcard-free handlers</div>
              <div class="comp-cell">OpenAPI / Zod schemas; manual version coexistence</div>
              <div class="comp-cell">Serde enums; manual capability gating</div>
              <div class="comp-cell">Json.Decode decoders per client release</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Agent guardrails</div>
              <div class="comp-cell-hi">Blocks sorryAx, custom axioms, unhandled union cases, and broken proofs</div>
              <div class="comp-cell">Agent can cast `as any` or weaken test fixtures</div>
              <div class="comp-cell">Strong types, yet logic bugs pass `cargo check`</div>
              <div class="comp-cell">No runtime exceptions, yet business bugs compile</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Dead-code elimination</div>
              <div class="comp-cell-hi">Pure modules + Prop erasure + [proof-only, 0 B C] + LTO --gc-sections</div>
              <div class="comp-cell">JS bundler tree-shaking (limited by module side effects)</div>
              <div class="comp-cell">LLVM LTO + wasm-opt (strong, no proof erasure layer)</div>
              <div class="comp-cell">Elm Function-level DCE (web-only)</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Rendering model</div>
              <div class="comp-cell-hi">Real DOM (SSG + Wasm) & native OS widgets from one .lp/.css tree</div>
              <div class="comp-cell">Native mobile views + React DOM on web</div>
              <div class="comp-cell">Varies by toolkit (DOM, GTK/AppKit, or custom GPU canvas)</div>
              <div class="comp-cell">Browser virtual DOM only</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Read the manual</span>
          <h2 class="section-title">Written by engineers, structured around real deployments</h2>
          <p class="section-desc">
            Start with a 10-minute Release Checklist app, then walk through our core patterns for edge contracts, frontend-first rollouts, and Reservoir packages.
          </p>
        </div>
        <div class="cards-3">
          {clickableCard
            "Your first Lakeport app"
            "Create a project manifest, write a pure reducer and .lp TSX view, prove an item-count invariant, and pre-render static HTML."
            "Start tutorial ->"
            "/docs/getting-started"
            Icon.bolt}
          {clickableCard
            "Versioned union contracts"
            "Structure shared/ with dependent Request and Response families so adding Version.v3 guides every client and server update."
            "Read contract pattern ->"
            "/docs/versioned-contracts"
            Icon.layers}
          {clickableCard
            "Always release frontend first"
            "Ship capability-gated UI before enabling backend behavior so rolling deploys and emergency rollbacks stay uneventful."
            "Read release guide ->"
            "/docs/frontend-first-releases"
            Icon.shield}
        </div>
      </div>
    </section>
  </div>

/-! ## 2. Why Lean Page (`/why-lean`) -/

def whyLeanPage : V :=
  <div>
    <section class="hero-section">
      <div class="container">
        <div class="hero-grid">
          <div class="eyebrow"><span>Why Lean 4 for application teams</span></div>
          <h1 class="hero-title">Types catch shape mismatches. Proofs catch broken promises</h1>
          <p class="hero-lead">
            When people write code by hand, they get tired and miss edge cases. When coding agents write code at 200 tokens per second, they satisfy the compiler and unit tests by taking whatever shortcut passes fastest. Lean 4 lets you state the rules an agent is not allowed to break.
          </p>
          <div class="cta-row">
            {primaryBtn "Read pure core & proofs guide" (Ev.nav "/docs/pure-core-and-proofs")}
            {secondaryBtn "Try the homepage workbench" (Ev.nav "/")}
          </div>
        </div>
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Four practical advantages</span>
          <h2 class="section-title">What changes when your UI language has a proof kernel</h2>
        </div>
        <div class="cards-3">
          {staticCard
            "Zero spec-to-code gap"
            "In TLA+ or Alloy, you verify a whiteboard model and hope your TypeScript matches it. In Lakeport, StateLaws.lean imports State.lean and proves theorems directly over the exact step function compiled into app.wasm."
            Icon.shield}
          {staticCard
            "Productive witnesses catch dead gates"
            "Safety theorems prove nothing bad happens; productive witnesses prove good user flows still succeed. Together they stop an agent from fixing a bug by silently rejecting valid commands."
            Icon.bolt}
          {staticCard
            "Fast C & Wasm via Perceus"
            "Lean 4 compiles to C with Perceus reference counting and opportunistic in-place reuse rather than stop-the-world GC pauses, producing predictable frame budgets on web and native shells."
            Icon.layers}
        </div>
      </div>
    </section>

    <section class="section-subtle">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Honest assurance</span>
          <h2 class="section-title">What is proved by the Lean kernel vs. what sits in the trusted base</h2>
          <p class="section-desc">
            We do not print '100% Verified' stickers. Every Lakeport project separates kernel-checked pure logic from the small imperative host shell that talks to the browser or OS.
          </p>
        </div>
        <div class="comp-wrap">
          <div class="comp-table">
            <div class="comp-head-row">
              <div class="comp-cell-label">Layer</div>
              <div class="comp-cell-hi">Verification mechanism</div>
              <div class="comp-cell">Runtime byte cost</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">URL & wire codecs</div>
              <div class="comp-cell-hi">Kernel-checked LawfulUrlCodec & WirePack round-trip theorems</div>
              <div class="comp-cell">Proofs erased (0 B); compact codec functions only</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Capability gates & reducers</div>
              <div class="comp-cell-hi">Kernel-checked conservation, socket-lock, and gate denial theorems (0 sorryAx)</div>
              <div class="comp-cell">[proof-only, 0 B C] law modules omitted from link</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Subtree memoization</div>
              <div class="comp-cell-hi">MemoCell.refresh_get observational equivalence proof</div>
              <div class="comp-cell">Equality witness in Prop erases to 0 B</div>
            </div>
            <div class="comp-row">
              <div class="comp-cell-label">Compiler & host shell (TCB)</div>
              <div class="comp-cell-hi">Differential tests, conformance suites, hydration parity checks (not kernel-proved)</div>
              <div class="comp-cell">Shared boot.mjs / dom-renderer.mjs or native C host</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>

/-! ## 3. Ecosystem & Reservoir Page (`/ecosystem`) -/

def ecosystemPage (s : AppState) : V :=
  let parsedSandbox := s.sandboxCache.get
  <div>
    <section class="hero-section">
      <div class="container">
        <div class="hero-grid">
          <div class="eyebrow"><span>Reservoir packages & pure-Lean MDX</span></div>
          <h1 class="hero-title">Grow the ecosystem freely. Ship only the functions you call</h1>
          <p class="hero-lead">
            Because pure Lean modules have no import-time side effects, Lakeport packages on Reservoir can include rich parsers, component helpers, and hundreds of theorems while linking only the exact declarations reachable from App.app.
          </p>
        </div>
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Live Reservoir module demo: lakeport-mdx</span>
          <h2 class="section-title">Edit MDX below and watch pure Lean Wasm parse and highlight it live</h2>
          <p class="section-desc">
            This website renders all 12 documentation chapters with packages/lakeport-mdx: zero remark, zero shiki, and zero JavaScript markdown bundles. Type into the editor on the left to test the live Wasm parser.
          </p>
        </div>
        <div class="seg-group">
          <button class="seg-btn" data-active={true} onClick={Ev.sandboxPreset "default"}>Preset: Callout + theorem</button>
          <button class="seg-btn" data-active={false} onClick={Ev.sandboxPreset "contract"}>Preset: Markdown table + handler</button>
        </div>
        <div class="sandbox-split">
          <div class="sandbox-editor-pane">
            <div class="wb-pane-head">
              <span>Live .mdx source</span>
              <span>{toString parsedSandbox.blocks.length ++ " AST blocks | " ++ toString parsedSandbox.toc.length ++ " TOC anchors"}</span>
            </div>
            <textarea
              class="sandbox-textarea"
              label="MDX sandbox source"
              placeholder="Write Markdown, ```lean code fences, or <Callout> blocks..."
              value={s.sandboxSource}
              field={2}
            />
          </div>
          <div class="sandbox-preview-pane">
            {renderBlocks (mdxHooks s) parsedSandbox.blocks}
          </div>
        </div>
      </div>
    </section>

    <section class="section-subtle">
      <div class="container">
        <div class="section-head">
          <span class="section-kicker">Five-layer dead-code elimination</span>
          <h2 class="section-title">Explore how Lean strips unused Reservoir declarations and all proofs</h2>
          <p class="section-desc">
            Toggle optional packages and usage profiles below to inspect how Prop erasure, [proof-only, 0 B C] law omission, and wasm-ld --gc-sections keep release bundles lean.
          </p>
        </div>
        {deadCodeExplorerView s.dce}
      </div>
    </section>
  </div>

/-! ## 4. Showcase & Reference Architectures (`/showcase`) -/

def showcasePage : V :=
  <div>
    <section class="hero-section">
      <div class="container">
        <div class="hero-grid">
          <div class="eyebrow"><span>Reference architectures</span></div>
          <h1 class="hero-title">Production-grade apps built end to end in Lakeport</h1>
          <p class="hero-lead">
            Every architectural pattern in our manual comes directly from full Lakeport applications with shared edge contracts, static pre-rendering, and kernel-checked state laws.
          </p>
        </div>
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        <div class="cards-3">
          {clickableCard
            "lakeport-www (this site)"
            "Marketing workbench + 12-chapter MDX manual. Built with site-contract (dependent Version.v1/v2 wire union), lakeport-mdx (scoped CSS module + lossless highlighter), MemoCell caching, and 17 SSG pre-rendered routes."
            "Inspect CLI & repo guide ->"
            "/docs/cli-and-mcp"
            Icon.book}
          {clickableCard
            "Harbor Chat v3"
            "Multi-community team chat with text channels, threaded replies, forum posts, voice stage state, offline outbox reconciliation, and HarborContract v1/v2 capability negotiation across 9 pre-rendered routes."
            "Study versioned contracts ->"
            "/docs/versioned-contracts"
            Icon.layers}
          {clickableCard
            "Escrow & Capability Workbench"
            "Interactive financial state machine demonstrating conservation proofs, mid-flight socket drop locks (.uncertain), fail-closed CAPS advertisements, and refutation of naive agent retry patches."
            "Launch live workbench ->"
            "/"
            Icon.shield}
        </div>
      </div>
    </section>
  </div>

end Site.Marketing
