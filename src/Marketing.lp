import LakeportMdx
import State
import Events
import Brand
import Widgets
set_option synthInstance.maxSize 4096
/-!
# `Site.Marketing` — Editorial Marketing Routes (`/`, `/why-lean`, `/ecosystem`, `/showcase`)

Art-directed around Lakeport's concluded brand identity (`Mist`, `Abyss`, `Deep`,
`Lake`, `Shallows`, `Foam`, `Beacon`, `Geist` + `Schibsted Grotesk` + `JetBrains Mono`)
and one architectural waterline transition per page.
-/
namespace Site.Marketing
open LakeportStyle LakeportMdx Site Site.Demo Site.Brand Site.Widgets

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

/-! ## 1. `/` — Homepage -/

def homePage (s : AppState) : V :=
  <main>
    <section class="hero-air hero-home">
      <div class="container hero-home-grid">
        <div class="hero-copy-col">
          <h1 class="display-xl">
            <span>{"Apps your agents "}</span>
            <span class="brand-phrase">can prove.</span>
          </h1>
          <p class="lead-editorial">
            Lakeport compiles Lean 4 views, edge contracts, and domain logic to WebAssembly and native apps. When an agent edits a state machine or wire schema, the Lean kernel checks your invariants before a build can pass.
          </p>
          <div class="cta-row">
            {primaryBtn "Build your first app" (Ev.nav "/docs/getting-started")}
            {inlineLinkBtn "Read the docs →" (Ev.nav "/docs/introduction")}
          </div>
        </div>

        <div class="hero-mark-col">
          {heroWaterlineMark}
        </div>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="water-zone">
      <div class="container">
        <div class="theorem-strip">
          <div class="theorem-strip-code">
            <span class="mono-kicker">CHECKED IN THIS REPOSITORY · SRC/DEMO/WORKBENCHLAWS.LEAN</span>
            <div class="theorem-pre">
              <span class="syn-kw">{"theorem "}</span>
              <span class="syn-fn">verified_nonreset_conserves</span>
              <span>{" (srv : ServerMode) (l : Ledger)\n    (act : LedgerAction) (hAct : act ≠ .reset)\n    (hInv : LedgerConserved l 10000) :\n    "}</span>
              <span class="syn-ty">{"LedgerConserved ((stepVerifiedLedger srv l act).1) 10000"}</span>
            </div>
          </div>
          <div class="theorem-strip-ev">
            {evidenceItem .proved "verified_nonreset_conserves · 0 custom axioms"}
            {evidenceItem .trusted "Lean 4.35 kernel, clang wasm32, DOM host" false}
          </div>
        </div>

        <div class="water-demo-head">
          <h2 class="display-lg">One retry. $25 missing.</h2>
          <p class="water-lead">
            A dropped socket during checkout is where optimistic retry patches quietly lose conservation. Run the faulty agent patch below in live WebAssembly, then compare the reducer guarded by Lean.
          </p>
        </div>

        {workbenchVesselView s.workbench}
      </div>
    </section>

    <section class="editorial-section">
      <div class="container split-5-7">
        <div class="editorial-col">
          <h2 class="display-lg">Old clients don’t break.</h2>
          <p class="body-editorial">
            A browser tab can stay open for days while backend pods roll forward. In Lakeport, client and server share one versioned union contract: adding a wire version fails to compile until every handler covers it, and new capabilities stay dark until advertised at runtime.
          </p>

          <div class="compile-specimen">
            <span class="mono-kicker">NEGATIVE COMPILE CHECK · TESTS/CHECK-NEGATIVE-V3.PY</span>
            <span class="compile-err-line">error: missing cases: Site.Contract.Version.v3</span>
            <span class="compile-caption">Verified in npm test by compiling an unhandled Version.v3 fixture against Lean.</span>
          </div>

          <div class="inline-links-row">
            {inlineLinkBtn "Versioned contracts →" (Ev.nav "/docs/versioned-contracts")}
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
              <span class="mono-kicker">BUILD RECEIPT · LAKEPORT-WWW</span>
              <span class="receipt-sub">dist/web/wasm/app_lp2.wasm</span>
            </div>
            <div class="spec-rows">
              <div class="spec-row">
                <span class="spec-key">Checked theorems</span>
                {evidenceItem .proved "39 theorems across 4 Lean libraries (0 sorryAx)"}
              </div>
              <div class="spec-row">
                <span class="spec-key">Proof runtime cost</span>
                {evidenceItem .proved "0 B emitted in C and WebAssembly"}
              </div>
              <div class="spec-row">
                <span class="spec-key">Static HTML routes</span>
                <span class="spec-mono">17 SSG routes hydrated in place at commit 0</span>
              </div>
              <div class="spec-row">
                <span class="spec-key">Site Wasm bundle</span>
                {evidenceItem .trusted "463 KB gzipped · 2.33 MB raw release binary"}
              </div>
              <div class="spec-row">
                <span class="spec-key">Per-package attribution</span>
                {evidenceItem .unknown "Whole-program LTO · see modeled slices in Packages" false}
              </div>
            </div>
          </div>
        </div>

        <div class="editorial-col">
          <h2 class="display-lg">Ship only what you call.</h2>
          <p class="body-editorial">
            Proofs live in Prop and erase before C code generation. Runtime functions compile into dead-stripped sections, so pulling a Lake package for one parser or codec never drags its unused modules into your output.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Explore packages & live MDX →" (Ev.nav "/ecosystem")}
          </div>

          <div class="authoring-list">
            <div class="authoring-row">
              <span class="authoring-term">Views (.lp)</span>
              <span class="authoring-desc">Typed TSX markup and scoped CSS compiled directly into Lean state transitions.</span>
            </div>
            <div class="authoring-row">
              <span class="authoring-term">Core (.lean)</span>
              <span class="authoring-desc">Shared wire codecs, capability gates, and pure reducers checked by the Lean kernel.</span>
            </div>
            <div class="authoring-row">
              <span class="authoring-term">Targets</span>
              <span class="authoring-desc">Pre-rendered HTML + WebAssembly for the web, plus native macOS, Linux, iOS, and Android hosts.</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="closing-section section-ruled">
      <div class="container closing-inner">
        <h2 class="display-md">Check it before it ships.</h2>
        <div class="cta-row">
          {primaryBtn "Build your first app" (Ev.nav "/docs/getting-started")}
          {inlineLinkBtn "Why Lean 4 →" (Ev.nav "/why-lean")}
          {inlineLinkBtn "Browse all 12 chapters →" (Ev.nav "/docs")}
        </div>
      </div>
    </section>
  </main>

/-! ## 2. `/why-lean` — Why Lean 4 for Application Software -/

def whyLeanPage : V :=
  <main>
    <section class="hero-air">
      <div class="container split-8-4">
        <div class="hero-copy-col">
          <h1 class="display-xl">
            <span>{"Types check the shape. "}</span>
            <span class="brand-phrase">Proofs check the promise.</span>
          </h1>
          <p class="lead-editorial">
            TypeScript and Rust catch mismatched fields. They cannot check whether an offline retry conserves money, a URL parser inverts its formatter, or an unnegotiated wire frame can escape to a legacy server.
          </p>
        </div>

        <aside class="pull-aside">
          <p class="pull-quote">
            <span class="accent-phrase">Code generation got cheap; reviewing subtle state bugs did not.</span>
            <span>{" Lean gives humans and coding agents a mechanical referee whose verdict does not depend on test coverage."}</span>
          </p>
        </aside>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="water-zone">
      <div class="container split-5-7">
        <div class="water-specimen-prose">
          <span class="mono-kicker">PRODUCT REQUIREMENT → KERNEL OBLIGATION</span>
          <h2 class="display-md">“A dropped connection never creates or destroys money.”</h2>
          <p class="water-lead">
            In an ordinary stack, that sentence lives in a design doc and hopes twenty unit tests approximate it. In Lakeport, it is a 12-line theorem over every constructor of LedgerAction and DeliveryStatus.
          </p>
        </div>

        <div class="water-specimen-code">
          <div class="specimen-vessel">
            <div class="wb-pane-bar">
              <span class="wb-pane-kicker">SRC/DEMO/WORKBENCHLAWS.LEAN</span>
              <span class="wb-file-path">0 custom axioms</span>
            </div>
            <div class="wb-code-body">
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-ln">01</span>
                <span class="wb-code-src">theorem verified_nonreset_conserves (srv : ServerMode) (l : Ledger)</span>
              </div>
              <div class="wb-code-line" data-tone="plain">
                <span class="wb-ln">02</span>
                <span class="wb-code-src">    (act : LedgerAction) (hAct : act ≠ .reset)</span>
              </div>
              <div class="wb-code-line" data-tone="guard">
                <span class="wb-ln">03</span>
                <span class="wb-code-src">    (hInv : LedgerConserved l 10000) :</span>
              </div>
              <div class="wb-code-line" data-tone="guard">
                <span class="wb-ln">04</span>
                <span class="wb-code-src">    LedgerConserved ((stepVerifiedLedger srv l act).1) 10000</span>
              </div>
              <div class="wb-code-line" data-tone="comment">
                <span class="wb-ln">05</span>
                <span class="wb-code-src">-- Discharged across all 6 non-reset actions without sorryAx</span>
              </div>
            </div>
            <div class="wb-code-foot">
              {evidenceItem .proved "verified_nonreset_conserves · kernel-checked"}
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="editorial-section">
      <div class="container">
        <div class="numbered-list">
          <div class="numbered-row">
            <span class="numbered-idx">01</span>
            <div class="numbered-head">
              <h2 class="display-sm">Agents get an unambiguous referee.</h2>
            </div>
            <p class="body-editorial">
              When an LLM agent refactors a wire protocol or optimistic reducer, green tests only prove the cases the author thought to write. Exhaustive pattern matching and targeted Lean theorems reject broken transitions locally, giving the agent exact goals to repair.
            </p>
          </div>

          <div class="numbered-row">
            <span class="numbered-idx">02</span>
            <div class="numbered-head">
              <h2 class="display-sm">Proofs stay at the seams that earn them.</h2>
            </div>
            <p class="body-editorial">
              Nobody wants to write tactics about padding or typography. Lakeport separates .lp views and scoped .css from pure .lean domain modules so you spend proof effort solely on codecs, capability gates, routing bijections, and state invariants.
            </p>
          </div>

          <div class="numbered-row">
            <span class="numbered-idx">03</span>
            <div class="numbered-head">
              <h2 class="display-sm">Verification erases to zero runtime bytes.</h2>
            </div>
            <p class="body-editorial">
              Lean distinguishes computational data (Type) from logical propositions (Prop). Every theorem in your codebase is checked at build time and erased completely before Lean emits C for WebAssembly or native targets.
            </p>
          </div>
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container split-4-8">
        <div class="editorial-col">
          <h2 class="display-md">An explicit trust boundary.</h2>
          <p class="body-editorial">
            Lakeport never claims that “everything is proved.” Every verification surface distinguishes kernel-checked theorems from trusted compilers and runtime hosts.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Pure core & proofs guide →" (Ev.nav "/docs/pure-core-and-proofs")}
          </div>
        </div>

        <div class="editorial-col">
          <div class="spec-rows">
            <div class="spec-row">
              <span class="spec-key">Domain & codecs</span>
              {evidenceItem .proved "Reducers, WirePack round-trips, URL codecs, SafeSlug, MemoCell" false}
            </div>
            <div class="spec-row">
              <span class="spec-key">Toolchain & host</span>
              {evidenceItem .trusted "Lean 4.35 kernel, C emitter, clang wasm32, DOM & WebSocket shims" false}
            </div>
            <div class="spec-row">
              <span class="spec-key">External environment</span>
              {evidenceItem .unknown "Live network partitions, user clock skew, third-party APIs" false}
            </div>
            <div class="spec-row">
              <span class="spec-key">Refuted transitions</span>
              {evidenceItem .failed "Counterexamples caught at compile time (e.g. stepBuggyAgentRetry)" false}
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

/-! ## 3. `/ecosystem` — Packages & Live Pure-Lean MDX -/

def ecosystemPage (s : AppState) : V :=
  let parsedSandbox := (s.sandboxCache.refresh s.sandboxSource).get
  <main>
    <section class="hero-air hero-packages">
      <div class="container">
        <div class="packages-intro">
          <h1 class="display-xl">
            <span>{"Packages that don’t "}</span>
            <span class="brand-phrase">cost you bytes.</span>
          </h1>
          <p class="lead-editorial">
            Pull Lean packages from Lake and Reservoir—parsers, codecs, state machines, and theorem suites—knowing proofs erase completely and unreferenced declarations drop at link time.
          </p>
        </div>

        <div class="mdx-author-box">
          <div class="mdx-bar-light">
            <div class="mdx-bar-left">
              <span class="mono-kicker">AUTHORED .MDX INPUT · PACKAGES/LAKEPORT-MDX</span>
              <span class="beacon-live-tag">● Live on keystroke</span>
            </div>
            <div class="seg-group">
              <button class="seg-btn" data-active={s.sandboxPreset != "contract"} onClick={Ev.sandboxPreset "notes"}>
                Preset: Release notes
              </button>
              <button class="seg-btn" data-active={s.sandboxPreset == "contract"} onClick={Ev.sandboxPreset "contract"}>
                Preset: Contract table
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
            <span class="mono-kicker">COMPILED OUTPUT · RENDERED BY APP_LP2.WASM</span>
            <span class="mdx-ast-count">
              {toString parsedSandbox.blocks.length ++ " AST blocks · " ++ toString parsedSandbox.toc.length ++ (if parsedSandbox.toc.length == 1 then " heading anchor" else " heading anchors")}
            </span>
          </div>
          {evidenceItem .proved "LakeportMdx/MdxLaws.lean · 6 theorems (SafeSlug + TOC coherence)"}
        </div>

        <div class="mdx-water-surface">
          {renderBlocks (mdxHooks s) parsedSandbox.blocks}
        </div>
      </div>
    </section>

    <section class="editorial-section">
      <div class="container split-4-8">
        <div class="editorial-col">
          <h2 class="display-lg">Dead code stays dead.</h2>
          <p class="body-editorial">
            Proofs never enter C codegen, and reachable functions compile into isolated sections stripped by wasm-ld --gc-sections. Toggle optional packages on the right to inspect how declaration reachability behaves alongside this site’s actual 463 KB gzipped Wasm binary.
          </p>
          <div class="inline-links-row">
            {inlineLinkBtn "Reservoir & bundle size chapter →" (Ev.nav "/docs/reservoir-and-bundle-size")}
          </div>
        </div>

        <div class="editorial-col">
          {deadCodeExplorerView s.dce}
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container">
        <h2 class="display-md">Workspace libraries in this repository.</h2>
        <div class="module-ledger">
          <div class="module-row">
            <div class="module-name-col">
              <span class="module-name">site-contract</span>
              <span class="module-path">shared/SiteContract/</span>
            </div>
            <p class="module-desc">
              Versioned client/server union wire protocol (lpw1, lpw2), fail-closed CAPS capability advertisement parser, and pre-socket command admission gate.
            </p>
            <div class="module-ev-col">
              {evidenceItem .proved "16 theorems · 0 sorryAx"}
            </div>
          </div>

          <div class="module-row">
            <div class="module-name-col">
              <span class="module-name">lakeport-mdx</span>
              <span class="module-path">packages/lakeport-mdx/</span>
            </div>
            <p class="module-desc">
              Pure Lean 4 Markdown/MDX parser, YAML frontmatter extractor, Lean 4 syntax highlighter, and typed component embedder powering all 12 manual chapters with zero JS markdown dependencies.
            </p>
            <div class="module-ev-col">
              {evidenceItem .proved "6 theorems · 0 sorryAx"}
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

/-! ## 4. `/showcase` — Examples & Reference Codebases -/

def showcasePage : V :=
  <main>
    <section class="hero-air">
      <div class="container">
        <div class="packages-intro">
          <h1 class="display-xl">
            <span>{"Three checked projects "}</span>
            <span class="brand-phrase">you can read end to end.</span>
          </h1>
          <p class="lead-editorial">
            Inspectable codebases from the Lakeport workspace—showing where Lean proofs earn their keep and how views, routes, and offline queues fit together.
          </p>
        </div>
      </div>
    </section>

    <section class="editorial-section section-ruled">
      <div class="container">
        <div class="case-list">
          <div class="case-row">
            <div class="case-meta-col">
              <span class="numbered-idx">01</span>
              <h2 class="display-sm">lakeport.dev (this site)</h2>
              <span class="case-fact">17 static SSG routes · 463 KB gzipped Wasm</span>
              <span class="case-fact">src/ + packages/lakeport-mdx/</span>
            </div>
            <div class="case-body-col">
              <p class="body-editorial">
                Both the marketing experience and the 12-chapter documentation manual are authored in .lp TSX, scoped .css, and pure-Lean MDX. Every route pre-renders to static HTML at build time and hydrates in place at commit 0 against a single compiled Lean WebAssembly module.
              </p>
              <div class="inline-links-row">
                {inlineLinkBtn "Routing & SSG chapter →" (Ev.nav "/docs/routing-and-ssg")}
                {inlineLinkBtn "Open live MDX parser →" (Ev.nav "/ecosystem")}
              </div>
            </div>
          </div>

          <div class="case-row">
            <div class="case-meta-col">
              <span class="numbered-idx">02</span>
              <h2 class="display-sm">Escrow & capability workbench</h2>
              <span class="case-fact">lpw1 / lpw2 union · 28 domain theorems</span>
              <span class="case-fact">shared/SiteContract/ + src/Demo/</span>
            </div>
            <div class="case-body-col">
              <p class="body-editorial">
                Models a financial checkout seam under dropped sockets and rolling backend deployments. Pairs an executable counterexample for a faulty optimistic retry with a kernel-checked reducer that locks uncertain transfers and blocks unnegotiated v2 frames before they hit the wire.
              </p>
              <div class="inline-links-row">
                {inlineLinkBtn "Run live workbench →" (Ev.nav "/")}
                {inlineLinkBtn "Versioned contracts chapter →" (Ev.nav "/docs/versioned-contracts")}
              </div>
            </div>
          </div>

          <div class="case-row">
            <div class="case-meta-col">
              <span class="numbered-idx">03</span>
              <h2 class="display-sm">Workspace Board & Lakeport Chat</h2>
              <span class="case-fact">Web + macOS + Linux + iOS + Android</span>
              <span class="case-fact">examples/workspace-board · examples/lakeport-chat</span>
            </div>
            <div class="case-body-col">
              <p class="body-editorial">
                Multi-target reference apps in the main Lakeport repository: a multi-column Kanban board with pointer/HTML5 drag-and-drop and persistent SQLite outbox queues, alongside a streaming chat client reconciling optimistic local turns with server acknowledgements.
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
          <span class="mono-kicker">VERIFICATION LEDGER ACROSS EXAMPLES</span>
          <h2 class="display-md">What is proved, and what is trusted.</h2>
        </div>

        <div class="water-spec-rows">
          <div class="water-spec-row">
            <span class="water-spec-key">lakeport-www routing & cache</span>
            {evidenceItem .proved "LawfulUrlCodec round-trip + MemoCell coherence (5 theorems)"}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Site.Contract wire & gate</span>
            {evidenceItem .proved "Codec round-trips + fail-closed CAPS + gate rejection (16 theorems)"}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Escrow state machine</span>
            {evidenceItem .proved "Conservation + flight lock + retry counterexample (12 theorems)"}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">LakeportMdx heading slugs</span>
            {evidenceItem .proved "SafeSlug character safety + TOC anchor coherence (6 theorems)"}
          </div>
          <div class="water-spec-row">
            <span class="water-spec-key">Compilers & platform hosts</span>
            {evidenceItem .trusted "Lean 4.35 kernel, clang wasm32/native, DOM & native shell hosts" false}
          </div>
        </div>

        <div class="water-closing-cta">
          {primaryBtn "Build your first app" (Ev.nav "/docs/getting-started")}
          {inlineLinkBtn "Browse documentation →" (Ev.nav "/docs/introduction")}
        </div>
      </div>
    </section>
  </main>

end Site.Marketing
