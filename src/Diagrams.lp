import State
import Events
import Brand
set_option synthInstance.maxSize 4096
/-!
# `Site.Diagrams` : Architectural Diagrams for Section 4 (`How Lakeport is built`)

Renders three responsive, brand-token diagrams embedded directly in `.mdx` chapters:
1. `<ArchLayersDiagram />`: 4-tier package and ABI stack (`17` packages across app, SDKs, kernel, hosts)
2. `<BuildPipelineDiagram />`: 7-stage `lakeport check` and `lakeport build web --release` pipeline
3. `<Lp2AbiDiagram />`: Single-frame `LP2` v4 event, capacity-rollback, and two-phase `ack` cycle
-/
namespace Site.Diagrams
open LakeportStyle Site Site.Brand

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

private def pill (txt : String) : V :=
  <span class="diag-pill">{txt}</span>

def archLayersDiagram : V :=
  <div class="diag-card">
    <div class="diag-head">
      <span class="widget-title">Lakeport 4-Tier Architecture Stack</span>
      <span class="widget-sub">packages/ layout across compiler, verified kernel, and host shells</span>
    </div>

    <div class="diag-stack">
      <div class="diag-tier">
        <div class="diag-tier-top">
          <span class="diag-tier-tag">Tier 1: Application Workspace</span>
          {evidenceItem .proved "Proof modules erase to 0 B in C and Wasm" false}
        </div>
        <p class="diag-tier-desc">
          Your repo holds JSX-style .lp views, standard .css stylesheets, pure Model / step reducers, and optional *Laws.lean proof files.
        </p>
        <div class="diag-pills">
          {pill "src/*.lp"}
          {pill "src/app.css"}
          {pill "src/*.lean"}
          {pill "src/*Laws.lean ([proof-only, 0 B C])"}
        </div>
      </div>

      <div class="diag-connector">
        <span>{"↓ Lowered by LpTsx.lean (1:1 line map) & auto-imported by Toolchain.lean"}</span>
      </div>

      <div class="diag-tier">
        <div class="diag-tier-top">
          <span class="diag-tier-tag">Tier 2: Auto-Imported Lean SDKs & Optional Plugins</span>
          {evidenceItem .proved "Kernel-checked codecs, MemoCell, Outbox, and LPST diff" false}
        </div>
        <p class="diag-tier-desc">
          Five pure Lean SDKs prepend automatically to every module; three capability plugins bind native/web transports and sensors.
        </p>
        <div class="diag-pills">
          {pill "lakeport-style"}
          {pill "lakeport-router"}
          {pill "lakeport-effects"}
          {pill "lakeport-json"}
          {pill "lakeport-xml"}
          {pill "@lakeport/transport"}
          {pill "@lakeport/media-device"}
          {pill "@lakeport/on-device-ai"}
        </div>
      </div>

      <div class="diag-connector">
        <span>{"↓ Erases StyledView to 4-node ViewApi + binary LPST style trailer"}</span>
      </div>

      <div class="diag-tier diag-tier-seam">
        <div class="diag-tier-top">
          <span class="diag-tier-tag">Tier 3: Frozen Verified Kernel & LP2 v4 C Seam (643 LOC C11)</span>
          {evidenceItem .proved "Epoch/Ticket admission + pure RejectX.capacity rollback" false}
        </div>
        <p class="diag-tier-desc">
          Frozen 4-constructor ViewApi (.text, .button, .input, .group), fuel-bounded signals, LPDT framing, and static C buffers in lp2_shim.c.
        </p>
        <div class="diag-pills">
          {pill "lakeport-core"}
          {pill "lakeport-signals"}
          {pill "lakeport-codec"}
          {pill "lakeport-session"}
          {pill "lakeport-web (lp2_shim.c)"}
        </div>
      </div>

      <div class="diag-connector">
        <span>{"↕ LP2 v4 binary protocol (64 KiB LPRQ in, 1 MiB Reply2 + 1 MiB LPSN out)"}</span>
      </div>

      <div class="diag-tier">
        <div class="diag-tier-top">
          <span class="diag-tier-tag">Tier 4: Imperative Platform Host Shells</span>
          {evidenceItem .trusted "Web DOM production-ready; native shells have open gates" false}
        </div>
        <p class="diag-tier-desc">
          Each target host parses Reply2 + LPST frames, renders native widgets or DOM nodes, and executes outbound EffectReq tasks.
        </p>
        <div class="diag-pills">
          {pill "Web: boot.mjs + dom-renderer.mjs"}
          {pill "Linux: 15.9k LOC C11 GTK4/Pango"}
          {pill "Android: JNI + Java .lpcss"}
          {pill "iOS/macOS: Swift UIKit/AppKit"}
          {pill "Windows: Win32 Direct2D C++"}
        </div>
      </div>
    </div>
  </div>

def buildPipelineDiagram : V :=
  <div class="diag-card">
    <div class="diag-head">
      <span class="widget-title">Compiler & WebAssembly Release Pipeline</span>
      <span class="widget-sub">packages/lakeport-cli/Lakeport/Cli/Build.lean</span>
    </div>

    <div class="diag-phase-label">Phase A: lakeport check (fast verification loop)</div>
    <div class="diag-steps-grid">
      <div class="diag-step">
        <span class="diag-step-num">Stage 1</span>
        <span class="diag-step-title">Manifest & CSS Index</span>
        <p class="diag-step-body">
          Reads lakefile.toml, resolves .lp platform variants, indexes global CSS classes, and scopes import_css modules with a 6-hex SHA-256 hash.
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">Stage 2</span>
        <span class="diag-step-title">1:1 Line-Preserving .lp Lowering</span>
        <p class="diag-step-body">
          LpTsx.lean lowers JSX into StyledView calls and hoists static _lp_ns_k NodeStyle constants onto the final import line so Lean line numbers match.
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">Stage 3</span>
        <span class="diag-step-title">Wave-Parallel Lean Check</span>
        <p class="diag-step-body">
          Elaborates dependency waves across worker processes. Leaf *Laws.lean modules verify theorems and skip -c C emission ([proof-only, 0 B C]).
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">Stage 4</span>
        <span class="diag-step-title">.ilean BFS & Float Scan</span>
        <p class="diag-step-body">
          Walks .ilean references from App.app to flag unreferenced declarations and scans runtime modules to enforce deterministic zero-Float state.
        </p>
      </div>
    </div>

    <div class="diag-phase-label">Phase B: lakeport build web --release (code generation & SSG)</div>
    <div class="diag-steps-grid diag-steps-three">
      <div class="diag-step">
        <span class="diag-step-num">Stage 5</span>
        <span class="diag-step-title">32-Bit Wasm C Rewrite</span>
        <p class="diag-step-body">
          WasmNatLit.lean rewrites [2^31, 2^63) Nat literals for wasm32 with an exact textual inverse check, plus --wrap=lean_string_data for empty strings.
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">Stage 6</span>
        <span class="diag-step-title">Clang LTO & wasm-opt</span>
        <p class="diag-step-body">
          Compiles reachable C files with emcc -Oz -flto -Wl,--gc-sections, runs Binaryen wasm-opt -Oz, and audits the 18 exported LP2 C symbols.
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">Stage 7</span>
        <span class="diag-step-title">Node Wasm SSG Pre-Render</span>
        <p class="diag-step-body">
          ssg-prerender.mjs boots the compiled app_lp2.wasm binary in Node for every ssgRoutes entry and writes hydrated HTML with data-lp-id markers.
        </p>
      </div>
    </div>
  </div>

def lp2AbiDiagram : V :=
  <div class="diag-card">
    <div class="diag-head">
      <span class="widget-title">Single-Frame LP2 v4 Dispatch & Two-Phase Command Cycle</span>
      <span class="widget-sub">lp2_shim.c + lp2-abi.mjs + boot.mjs + dom-renderer.mjs</span>
    </div>

    <div class="diag-steps-grid">
      <div class="diag-step">
        <span class="diag-step-num">1. Inbound LPRQ</span>
        <span class="diag-step-title">Write 64 KiB g_input_buf</span>
        <p class="diag-step-body">
          Host JS encodes a button press, text edit, route change, or EffectResp into g_input_buf and invokes lp2_dispatch(byteLen).
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">2. Pure Step</span>
        <span class="diag-step-title">Capacity-Safe Evaluation</span>
        <p class="diag-step-body">
          StyledRoot.step evaluates with wideCaps. If the diff exceeds (publicCap, heldCap), state rolls back purely and returns RejectX.capacity so JS grows caps.
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">3. Token Readout</span>
        <span class="diag-step-title">1 MiB Pub + 1 MiB Held</span>
        <p class="diag-step-body">
          lp2-abi.mjs refreshes module.HEAPU8 after Wasm memory growth and checks lp2_output_status(token) before and after copying Reply2 + LPST + LPSN.
        </p>
      </div>
      <div class="diag-step">
        <span class="diag-step-num">4. Two-Phase Ack</span>
        <span class="diag-step-title">DOM Patch & Effect Release</span>
        <p class="diag-step-body">
          DomRenderer patches changed nodes; #runPlumbing() sends ack(gen, commit) to release staged EffectReq commands (fetch, KV, clipboard) to the browser.
        </p>
      </div>
    </div>
  </div>

end Site.Diagrams
