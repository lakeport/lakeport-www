import LakeportMdx
import State
import Events
import Brand
import Widgets
set_option synthInstance.maxSize 4096
/-!
# `Site.Marketing`: Official Brand Marketing Routes (`/`, `/why-lean`, `/ecosystem`, `/showcase`)

Adopts the approved Lakeport v1 brand kit:
- Primary `Lake / Port` logotype (`primaryLogo "hero"`) with >= 3.5u clear space
- Primary tagline `"Apps your agents can prove."` standing on the Shallows waterline,
  with its banded fading reflection resolving into the checked theorem + evidence status
- Strict four-state evidence discipline (`● proved`, `◐ trusted`, `○ unknown`, `✕ failed`)
  and honest platform/gate claims aligned to `docs/implementation/README.md`
-/
namespace Site.Marketing
open LakeportStyle LakeportMdx Site Site.Brand Site.Widgets

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

/-! ## 1. `/` : Homepage -/

def homePage (s : AppState) : V :=
  <main>
    <section class="hero-air hero-home">
      <div class="container hero-home-stack">
        <div class="hero-top-row">
          {primaryLogo "hero"}
          <div class="hero-intro-col">
            <p class="lead-editorial">
              Write JSX-style .lp views and plain CSS. State critical checkout, sync, or API rules in English, let your coding agent write the Lean state logic and proof, and check every branch before it ships. You do not need to know Lean to build with Lakeport.
            </p>
            <div class="cta-row">
              {primaryBtn "Start in 10 minutes" (Ev.nav "/docs/getting-started")}
              {inlineLinkBtn "Do I need to know Lean? →" (Ev.nav "/why-lean")}
              {inlineLinkBtn "Read the docs →" (Ev.nav "/docs/introduction")}
            </div>
          </div>
        </div>

        <h1 class="display-hero hero-waterline-title">
          <span>{"Apps your agents "}</span>
          <span class="brand-inline">can prove.</span>
        </h1>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="water-zone">
      <div class="container">
        <div class="waterline-reflection-band">
          <div class="waterline-reflection-text">Apps your agents can prove.</div>
          <div class="waterline-evidence-shelf">
            <div class="theorem-pre">
              <span class="syn-kw">{"theorem "}</span>
              <span class="syn-fn">lakeportFixed_never_overcharges</span>
              <span>{" (net : "}</span>
              <span class="syn-ty">NetworkRun</span>
              <span>{") : (runCheckout .lakeportFixed net).chargedCents ≤ "}</span>
              <span class="syn-num">2500</span>
              <span>{" := "}</span>
              <span class="syn-kw">by</span>
              <span>{" "}</span>
              <span class="syn-tac">cases</span>
              <span>{" net <;> "}</span>
              <span class="syn-tac">decide</span>
            </div>
            <div class="theorem-strip-ev">
              {evidenceItem .proved "Site.Demo.Laws.lakeportFixed_never_overcharges, Lean core axioms only" false}
              {evidenceItem .trusted "Lean 4.35 kernel, clang wasm32, and browser DOM" false}
              {evidenceItem .unknown "Live user Wi-Fi and remote payment gateway" false}
            </div>
          </div>
        </div>

        <div class="workflow-strip">
          <div class="workflow-step">
            <span class="workflow-num">Step 1</span>
            <span class="workflow-title">Write .lp views and CSS</span>
            <p class="workflow-desc">
              Build screens with typed JSX tags and regular stylesheets. Ordinary UI layout and styling require zero proofs.
            </p>
          </div>
          <div class="workflow-step">
            <span class="workflow-num">Step 2</span>
            <span class="workflow-title">Describe rules in English</span>
            <p class="workflow-desc">
              Tell Claude Code, Codex, or Cursor what must hold, such as never charging twice when Wi-Fi drops.
            </p>
          </div>
          <div class="workflow-step">
            <span class="workflow-num">Step 3</span>
            <span class="workflow-title">Check it before it ships</span>
            <p class="workflow-desc">
              Your agent writes the state logic and Lean proof. If an edge case breaks your rule, the compiler rejects the build.
            </p>
          </div>
        </div>

        <div class="water-demo-head">
          <h2 class="display-lg">Watch Lakeport catch a double-charge bug</h2>
          <p class="water-lead">
            Suppose you ask an agent to add auto-retry to a $25.00 checkout. Its unit test passes on normal Wi-Fi, so a typical pull request looks ready to merge. Test flaky Wi-Fi below to see what happens in compiled WebAssembly.
          </p>
        </div>

        {workbenchVesselView s.workbench}
      </div>
    </section>

    <section class="editorial-section">
      <div class="container split-5-7">
        <div class="editorial-col">
          <h2 class="display-lg">Old clients don't have to break</h2>
          <p class="body-editorial">
            Lakeport runs in your client app, while your server can be any Go, TypeScript, Python, Rust, or Rails service. A pattern we recommend is matching the contract in your client code against every API version still running in production.
          </p>
          <p class="body-editorial">
            When you list active versions such as v1 and v2 in that union contract, you can check before a backend release that dependent clients decode both formats and keep new v2 buttons gated until your server advertises them.
          </p>

          <div class="compile-specimen">
            <span class="compile-label">Compiler check when adding Version.v3 (tests/check-negative-v3.py)</span>
            <span class="compile-err-line">error: missing cases: Site.Contract.Version.v3</span>
            <span class="compile-caption">Adding a new active API version fails to compile until every client screen and decoder handles it.</span>
          </div>

          <div class="inline-links-row">
            {inlineLinkBtn "Versioned contracts pattern →" (Ev.nav "/docs/versioned-contracts")}
            {inlineLinkBtn "Frontend-first releases →" (Ev.nav "/docs/frontend-first-releases")}
          </div>
        </div>

        <div class="editorial-col">
          {rolloutTimelineView s.rolloutStage}
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container split-7-5">
        <div class="editorial-col">
          <div class="receipt-panel">
            <div class="receipt-head">
              <span class="widget-title">Three commands to adopt</span>
              <span class="receipt-sub">Plus actual build facts for lakeport.dev</span>
            </div>
            <div class="spec-rows">
              <div class="spec-row">
                <span class="spec-key">lakeport init my-app</span>
                <span class="spec-val">Creates starter .lp screens, .css styles, and coding-agent setup files.</span>
              </div>
              <div class="spec-row">
                <span class="spec-key">lakeport dev</span>
                <span class="spec-val">Runs a local dev server with automatic rebuilds and structured compiler feedback.</span>
              </div>
              <div class="spec-row">
                <span class="spec-key">lakeport mcp</span>
                <span class="spec-val">Gives your coding agent direct access to compiler checks and proof goals.</span>
              </div>
              <div class="spec-row">
                <span class="spec-key">Proof runtime cost</span>
                {evidenceItem .proved "0 bytes emitted in C or WebAssembly ([proof-only, 0 B C])" false}
              </div>
              <div class="spec-row">
                <span class="spec-key">This site's bundle</span>
                {evidenceItem .trusted "17 static HTML routes + compiled Lean WebAssembly" false}
              </div>
            </div>
          </div>
        </div>

        <div class="editorial-col">
          <h2 class="display-lg">Easy to adopt, small on the wire</h2>
          <p class="body-editorial">
            You do not need a rewrite or a proof background. Start with normal screens and CSS, connect your coding agent through MCP, and add checked rules only where money, offline state, or API versions can go wrong.
          </p>
          <p class="body-editorial">
            At build time, Lakeport strips all proof code completely and drops unreferenced package functions, so browsers download static HTML and one compact WebAssembly binary.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Try the live package & Markdown demo →" (Ev.nav "/ecosystem")}
            {inlineLinkBtn "CLI & MCP setup →" (Ev.nav "/docs/cli-and-mcp")}
          </div>
        </div>
      </div>
    </section>

    <section class="closing-section section-ruled">
      <div class="container closing-inner">
        <h2 class="display-md">Try Lakeport on a small web slice today</h2>
        <div class="cta-row">
          {primaryBtn "Start in 10 minutes" (Ev.nav "/docs/getting-started")}
          {inlineLinkBtn "Do I need to know Lean? →" (Ev.nav "/why-lean")}
          {inlineLinkBtn "Browse all 12 chapters →" (Ev.nav "/docs")}
        </div>
      </div>
    </section>
  </main>

/-! ## 2. `/why-lean` : Why Lean 4 (For Developers Who Do Not Write Lean) -/

def whyLeanPage : V :=
  <main>
    <section class="hero-air">
      <div class="container split-8-4">
        <div class="hero-copy-col">
          <h1 class="display-xl">
            <span>{"You don't need to know Lean "}</span>
            <span class="brand-phrase">to get its guarantees</span>
          </h1>
          <p class="lead-editorial">
            Most developers using Lakeport have never written a theorem prover tactic. You build components in JSX-style .lp files, describe critical rules in plain English, and let Lean check the code your agent writes.
          </p>
        </div>

        <div class="pull-aside">
          <p class="pull-quote">
            <span class="accent-phrase">Coding agents write features in seconds, and subtle retry bugs just as fast.</span>
            <span>{" TypeScript checks field types, while Lean checks whether a retry can double-charge a wallet or break an open tab."}</span>
          </p>
        </div>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="water-zone">
      <div class="container split-5-7">
        <div class="water-specimen-prose">
          <h2 class="display-md">Your day-to-day files look like regular frontend code</h2>
          <p class="water-lead">
            You edit .lp templates and .css stylesheets that read like React or Solid. When you touch a sensitive checkout or sync rule, you state the requirement in plain English and your agent maintains the Lean proof module beside it.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Views & .lp TSX guide →" (Ev.nav "/docs/views-and-tsx")}
            {inlineLinkBtn "Pure core & proofs guide →" (Ev.nav "/docs/pure-core-and-proofs")}
          </div>
        </div>

        <div class="water-specimen-code">
          <div class="specimen-vessel">
            <div class="wb-pane-bar">
              <span class="wb-pane-title">1. What you read and edit (src/Widgets.lp)</span>
              <span class="wb-file-path">JSX-style .lp</span>
            </div>
            <div class="wb-code-body">
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-code-src">{"<div class=\"wb-wallet-card\">"}</span>
              </div>
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-code-src">{"  <span class=\"wb-wallet-label\">Customer wallet</span>"}</span>
              </div>
              <div class="wb-code-line" data-tone="guard">
                <span class="wb-code-src">{"  <span class=\"wb-total-num\">{formatUsd out.walletCents}</span>"}</span>
              </div>
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-code-src">{"</div>"}</span>
              </div>
            </div>
            <div class="wb-pane-bar wb-pane-bar-mid">
              <span class="wb-pane-title">2. What your coding agent maintains (WorkbenchLaws.lean)</span>
              <span class="wb-file-path">Checked at build time</span>
            </div>
            <div class="wb-code-body">
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-code-src">theorem lakeportFixed_never_overcharges (net : NetworkRun) :</span>
              </div>
              <div class="wb-code-line" data-tone="guard">
                <span class="wb-code-src">    (runCheckout .lakeportFixed net).chargedCents ≤ 2500 := by</span>
              </div>
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-code-src">  {"  cases net <;> decide"}</span>
              </div>
            </div>
            <div class="wb-code-foot">
              {evidenceItem .proved "Site.Demo.Laws.lakeportFixed_never_overcharges, 0 custom axioms" false}
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="editorial-section">
      <div class="container">
        <div class="numbered-list">
          <div class="numbered-row">
            <div class="numbered-head">
              <h2 class="display-sm">Agents get exact errors instead of vague test failures</h2>
            </div>
            <p class="body-editorial">
              Unit tests only check the inputs someone remembered to write down. When an agent changes a state machine or API decoder in Lakeport, exhaustive pattern matching and Lean rules point directly to the unhandled branch so the agent can fix its own mistake in seconds.
            </p>
          </div>

          <div class="numbered-row">
            <div class="numbered-head">
              <h2 class="display-sm">Most of your UI code needs zero proofs</h2>
            </div>
            <p class="body-editorial">
              Nobody wants to prove theorems about button padding or dark mode colors. Lakeport separates .lp views and .css styles from pure state modules, so you only ask your agent for proofs on the parts that handle money, offline edits, URL routing, or API compatibility.
            </p>
          </div>

          <div class="numbered-row">
            <div class="numbered-head">
              <h2 class="display-sm">Proofs disappear completely at build time</h2>
            </div>
            <p class="body-editorial">
              Lean keeps runtime data separate from proof checks. Every theorem is verified during compilation and stripped out before Lean generates C code for WebAssembly or native runtime targets.
            </p>
          </div>
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container split-4-8">
        <div class="editorial-col">
          <h2 class="display-md">Four states, each with a shape and a word</h2>
          <p class="body-editorial">
            No tool can prove that Wi-Fi will stay up or a browser has zero bugs. Lakeport reports what was actually checked, lists what is trusted, and keeps incomplete gates visible instead of hiding them.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Pure core & proofs guide →" (Ev.nav "/docs/pure-core-and-proofs")}
          </div>
        </div>

        <div class="editorial-col">
          <div class="spec-rows">
            <div class="spec-row">
              <span class="spec-key">Kernel-checked models</span>
              {evidenceItem .proved "Checkout lock laws, v1/v2 wire codecs, URL round-trips, and MDX slugs" false}
            </div>
            <div class="spec-row">
              <span class="spec-key">Assumed & inventoried</span>
              {evidenceItem .trusted "Lean 4.35 kernel, clang wasm32, DOM renderer, and host browser APIs" false}
            </div>
            <div class="spec-row">
              <span class="spec-key">Not established yet</span>
              {evidenceItem .unknown "Live network drops, remote server uptime, and open native platform gates" false}
            </div>
            <div class="spec-row">
              <span class="spec-key">Gate did not pass</span>
              {evidenceItem .failed "Broken drafts rejected at compile time, such as stepBuggyAgentRetry" false}
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

/-! ## 3. `/ecosystem` : Packages & Live Markdown Demo -/

def ecosystemPage (s : AppState) : V :=
  let parsedSandbox := (s.sandboxCache.refresh (some s.sandboxSource)).get
  <main>
    <section class="hero-air hero-packages">
      <div class="container">
        <div class="packages-intro">
          <h1 class="display-xl">
            <span>{"Use shared packages "}</span>
            <span class="brand-phrase">without bloating your app</span>
          </h1>
          <p class="lead-editorial">
            Import Markdown parsers, wire codecs, or state helpers from Lake and Reservoir packages. Lakeport strips all proof code before C compilation and removes unused functions at link time.
          </p>
        </div>

        <div class="mdx-author-box">
          <div class="mdx-bar-light">
            <div class="mdx-bar-left">
              <span class="mdx-bar-title">Live Markdown & MDX input (packages/lakeport-mdx)</span>
              <span class="accent-live-tag">Parses on every keystroke</span>
            </div>
            <div class="seg-group">
              <button class="seg-btn" data-active={s.sandboxPreset != "contract"} onClick={Ev.sandboxPreset "notes"}>
                Preset: Release notes
              </button>
              <button class="seg-btn" data-active={s.sandboxPreset == "contract"} onClick={Ev.sandboxPreset "contract"}>
                Preset: API version table
              </button>
            </div>
          </div>
          <textarea
            class="sandbox-textarea"
            label="MDX sandbox source"
            placeholder="Write Markdown, ```lean code fences, tables, or <Callout> blocks..."
            value={s.sandboxSource}
            field={2}
          />
        </div>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="water-zone">
      <div class="container">
        <div class="mdx-water-head">
          <div class="mdx-water-meta">
            <h2 class="display-sm">Compiled WebAssembly output</h2>
            <span class="mdx-ast-count">
              {toString parsedSandbox.blocks.length ++ " blocks and " ++ toString parsedSandbox.toc.length ++ " headings parsed in WebAssembly"}
            </span>
          </div>
          {evidenceItem .proved "LakeportMdx.Laws.slugify_safe, heading anchors match [a-z0-9-]" false}
        </div>

        <div class="mdx-water-surface">
          {renderBlocks (mdxHooks s) parsedSandbox.blocks}
        </div>
      </div>
    </section>

    <section class="editorial-section">
      <div class="container split-4-8">
        <div class="editorial-col">
          <h2 class="display-lg">Unused package code drops out</h2>
          <p class="body-editorial">
            When you add a package for one helper or parser, you should not pay for the rest of the library. Toggle optional packages on the right to see how proof stripping and dead-code removal affect bundle size alongside this site's WebAssembly binary.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Packages & bundle size chapter →" (Ev.nav "/docs/reservoir-and-bundle-size")}
          </div>
        </div>

        <div class="editorial-col">
          {deadCodeExplorerView s.dce}
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container">
        <h2 class="display-md">Packages included in this repository</h2>
        <div class="module-ledger">
          <div class="module-row">
            <div class="module-name-col">
              <span class="module-name">site-contract</span>
              <span class="module-path">shared/SiteContract/</span>
            </div>
            <p class="module-desc">
              Client-side API contract covering active v1 and v2 formats, capability response parsing, and client feature gating before a request hits the socket.
            </p>
            <div class="module-ev-col">
              {evidenceItem .proved "16 theorems, 0 sorryAx" false}
            </div>
          </div>

          <div class="module-row">
            <div class="module-name-col">
              <span class="module-name">lakeport-mdx</span>
              <span class="module-path">packages/lakeport-mdx/</span>
            </div>
            <p class="module-desc">
              Markdown and MDX parser, frontmatter reader, Lean syntax highlighter, and interactive widget embedder that powers all 12 manual chapters without JavaScript markdown dependencies.
            </p>
            <div class="module-ev-col">
              {evidenceItem .proved "6 theorems, 0 sorryAx" false}
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

/-! ## 4. `/showcase` : Examples & Reference Codebases -/

def showcasePage : V :=
  <main>
    <section class="hero-air">
      <div class="container">
        <div class="packages-intro">
          <h1 class="display-xl">
            <span>{"Real examples you can read "}</span>
            <span class="brand-phrase">and check locally</span>
          </h1>
          <p class="lead-editorial">
            Explore working codebases in the Lakeport workspace to see how .lp JSX views, standard CSS, client contracts, and agent-maintained Lean rules fit together, along with which platform gates remain open.
          </p>
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container">
        <div class="case-list">
          <div class="case-row">
            <div class="case-meta-col">
              <h2 class="display-sm">lakeport.dev (this site)</h2>
              <span class="case-fact">17 static HTML pages + compiled Lean Wasm</span>
              <span class="case-fact">src/ and packages/lakeport-mdx/</span>
            </div>
            <div class="case-body-col">
              <p class="body-editorial">
                Both these marketing pages and the 12-chapter manual are built in .lp views, standard .css, and LakeportMdx. Every route pre-renders to static HTML at build time and attaches to one compiled WebAssembly binary in the browser.
              </p>
              <div class="inline-links-row">
                {inlineLinkBtn "Routing & SSG chapter →" (Ev.nav "/docs/routing-and-ssg")}
                {inlineLinkBtn "Open live Markdown demo →" (Ev.nav "/ecosystem")}
              </div>
            </div>
          </div>

          <div class="case-row">
            <div class="case-meta-col">
              <h2 class="display-sm">Checkout & API rollout models</h2>
              <span class="case-fact">v1/v2 union contract, 31 kernel-checked theorems</span>
              <span class="case-fact">shared/SiteContract/ and src/Demo/</span>
            </div>
            <div class="case-body-col">
              <p class="body-editorial">
                These pure Lean modules power the flaky-Wi-Fi checkout simulator and the backend rollout timeline on the home page. You can compare the agent's buggy first draft against the checked version and see how client contracts protect open browser tabs during backend releases.
              </p>
              <div class="inline-links-row">
                {inlineLinkBtn "Try the checkout simulator →" (Ev.nav "/")}
                {inlineLinkBtn "Versioned contracts chapter →" (Ev.nav "/docs/versioned-contracts")}
              </div>
            </div>
          </div>

          <div class="case-row">
            <div class="case-meta-col">
              <h2 class="display-sm">Workspace Board & runtime probes</h2>
              <span class="case-fact">Web Wasm demo + bounded runtime probes</span>
              <span class="case-fact">examples/workspace-board and examples/lakeport-chat</span>
            </div>
            <div class="case-body-col">
              <p class="body-editorial">
                In the main Lakeport repository, Workspace Board exercises a multi-column Kanban model over compiled Lean WebAssembly alongside bounded Android JNI and headless Windows/Linux runtime probes, while Lakeport Chat tests streaming transport contracts. Full six-platform UI framework support is not yet claimed.
              </p>
              <div class="inline-links-row">
                {inlineLinkBtn "Effects & offline queues →" (Ev.nav "/docs/effects-and-offline")}
                {inlineLinkBtn "Views & .lp TSX →" (Ev.nav "/docs/views-and-tsx")}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="water-zone">
      <div class="container">
        <div class="water-ledger-head">
          <h2 class="display-md">Evidence ledger for this repository</h2>
          <p class="water-lead">
            Every theorem below is checked during npm run check with Lean core axioms only (propext, Quot.sound) and zero proof bytes shipped in compiled C or WebAssembly.
          </p>
        </div>

        <div class="water-spec-rows">
          <div class="water-spec-row">
            <span class="water-spec-key">Site.Laws (routing & cache)</span>
            {evidenceItem .proved "URL codec round-trips and cached MDX refresh identity (5 theorems)" false}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Site.Contract.Laws (wire)</span>
            {evidenceItem .proved "v1/v2 wire round-trips and permitsEncodedFrame gates (16 theorems)" false}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Site.Demo.Laws (checkout)</span>
            {evidenceItem .proved "lakeportFixed_never_overcharges and ledger conservation (15 theorems)" false}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">LakeportMdx.Laws (anchors)</span>
            {evidenceItem .proved "slugify_safe and table-of-contents heading coherence (6 theorems)" false}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Toolchain & host browser</span>
            {evidenceItem .trusted "Lean 4.35 kernel, clang wasm32, browser DOM, and Cloudflare Worker shell" false}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Framework platform gates</span>
            {evidenceItem .unknown "Full native UI support (iOS, Android, macOS, Windows, Linux) and HMR" false}
          </div>
        </div>

        <div class="water-closing-cta">
          {primaryBtn "Start in 10 minutes" (Ev.nav "/docs/getting-started")}
          {inlineLinkBtn "Browse documentation →" (Ev.nav "/docs/introduction")}
        </div>
      </div>
    </section>
  </main>

end Site.Marketing
