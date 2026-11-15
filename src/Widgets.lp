import LakeportMdx
import SiteContract.Versions
import SiteContract.Api
import State
import Events
set_option synthInstance.maxSize 4096
/-!
# `Site.Widgets` — Interactive Wasm Workbench, Docs Simulators & Vector Icons

Pure `.lp` TSX components backed by `Site.Demo` and `Site.Contract`:
- `workbenchView`: Homepage "Agent Patch vs. Lean Kernel" live escrow & capability workbench
- `contractSimulatorView`: `<ContractSimulator />` embedded inside `04-versioned-contracts.mdx`
- `rolloutTimelineView`: `<RolloutTimeline />` embedded on `/` and `05-frontend-first-releases.mdx`
- `deadCodeExplorerView`: `<DeadCodeExplorer />` embedded on `/ecosystem` and `11-reservoir-and-bundle-size.mdx`
-/
namespace Site.Widgets
open LakeportStyle LakeportMdx Site Site.Contract Site.Demo

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

namespace Icon

def pathLine (d : String) : V :=
  <span data-lp-svg-shape="path" data-lp-d={d} data-lp-stroke="currentColor" data-lp-fill="none" data-lp-stroke-width="2" />

def pathSolid (d : String) : V :=
  <span data-lp-svg-shape="path" data-lp-d={d} data-lp-fill="currentColor" data-lp-stroke="none" />

def ring (cx cy r : String) : V :=
  <span data-lp-svg-shape="circle" data-lp-cx={cx} data-lp-cy={cy} data-lp-r={r} data-lp-stroke="currentColor" data-lp-fill="none" data-lp-stroke-width="2" />

def shield : List V := [
  pathLine "M12 3L19.5 6V11.5C19.5 16 16.3 19.6 12 21C7.7 19.6 4.5 16 4.5 11.5V6L12 3Z",
  pathLine "M8.8 12L11 14.2L15.4 9.8"
]

def bolt : List V := [pathSolid "M13.5 2L4.5 13.5H11L10 22L19.5 10H13L13.5 2Z"]
def layers : List V := [pathLine "M12 3L2 8L12 13L22 8L12 3ZM2 13L12 18L22 13M2 17.5L12 22.5L22 17.5"]
def book : List V := [pathLine "M4 5.5C4 4.4 4.9 3.5 6 3.5H19.5V19.5H6C4.9 19.5 4 20.4 4 21.5V5.5ZM4 19.5C4 18.4 4.9 17.5 6 17.5H19.5"]
def code : List V := [pathLine "M8.5 7L3.5 12L8.5 17M15.5 7L20.5 12L15.5 17"]
def sun : List V := [ring "12" "12" "4", pathLine "M12 2.5V5M12 19V21.5M2.5 12H5M19 12H21.5M5.3 5.3L7 7M17 17L18.7 18.7M5.3 18.7L7 17M17 7L18.7 5.3"]
def moon : List V := [pathLine "M20 14.2C18.9 14.8 17.6 15.1 16.3 15.1C12.2 15.1 8.9 11.8 8.9 7.7C8.9 6.4 9.2 5.1 9.8 4C6.2 5 3.5 8.2 3.5 12.1C3.5 16.7 7.3 20.5 11.9 20.5C15.8 20.5 19 17.8 20 14.2Z"]
def menu : List V := [pathLine "M4 6.5H20M4 12H20M4 17.5H20"]
def close : List V := [pathLine "M6 6L18 18M18 6L6 18"]
def search : List V := [ring "10.5" "10.5" "6.5", pathLine "M15.5 15.5L20.5 20.5"]

end Icon

def svg (size : String) (shapes : List V) : V :=
  <span class="svg-box" data-size={size} data-lp-svg="0 0 24 24">{shapes}</span>

def primaryBtn (label : String) (ev : UiEvent) : V :=
  <div class="btn-primary-wrap">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="btn-label">{label}</span>
  </div>

def secondaryBtn (label : String) (ev : UiEvent) : V :=
  <div class="btn-secondary-wrap">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="btn-label">{label}</span>
  </div>

/-! ## 1. Homepage WOW Workbench: Agent Patch vs. Lean Kernel -/

private def patchSnippet : AgentPatch → List String
  | .verified => [
      "-- src/Demo/Workbench.lean (Patch A: Kernel Accepted)",
      "def stepVerifiedLedger (srv : ServerMode) (l : Ledger) :",
      "    LedgerAction -> Ledger × WireLogEntry",
      "  | .instantRelease25 =>",
      "    let cmd := V2.ClientFrame.instantRelease cid 2500",
      "    if permitsV2Command (some srv.advertisement) cmd then",
      "      debitAvailableToReleased l 2500",
      "    else (l, blockedByGate cmd)",
      "  | .dropSocket =>",
      "    -- Keep delivery locked as .uncertain until reconciled",
      "    lockUncertainIfInFlight l",
      "",
      "theorem verified_nonreset_conserves (h : act != .reset) :",
      "    (stepVerifiedLedger srv l act).1.totalCents = l.totalCents"
    ]
  | .buggyRetry => [
      "-- Agent Patch B: clears lock on socket drop & retries debit",
      "def stepBuggyAgentRetry (l : Ledger) : Ledger :=",
      "  let l1 := { l with available := l.available - 2500,",
      "                     held := l.held + 2500 }",
      "  -- BUG: agent clears inFlight lock before server ack!",
      "  let l2 := { l1 with delivery := .idle }",
      "  -- Retry debits available a second time ($25.00 lost):",
      "  { l2 with available := l2.available - 2500,",
      "            delivery := .inFlight \"cid-2\" 2500 }",
      "",
      "theorem retry_conserves_cents (l : Ledger) :",
      "    (stepBuggyAgentRetry l).totalCents = l.totalCents := by",
      "  omega  -- X FAILS IN LEAN KERNEL"
    ]
  | .unhandledV3 => [
      "-- shared/SiteContract/Versions.lean (Agent adds v3)",
      "inductive Version where",
      "  | v1",
      "  | v2",
      "  | v3   -- Added for batch settlement",
      "",
      "-- shared/SiteContract/Api.lean (No wildcard arm!)",
      "def clientHandler : (v : Version) -> Handler v",
      "  | .v1 => { encode := V1.encodeReq, decode := V1.decodeResp }",
      "  | .v2 => { encode := V2.encodeReq, decode := V2.decodeResp }",
      "  -- X Missing case: Version.v3"
    ]

private def patchTone : AgentPatch → String
  | .verified => "ok"
  | .buggyRetry => "err"
  | .unhandledV3 => "warn"

def workbenchView (wb : WorkbenchState) : V :=
  let activeLedger := wb.buggyPreview.getD wb.ledger
  let total := activeLedger.totalCents
  let broken := total != 10000
  let instantAllowed := permitsV2Command (some wb.server.advertisement) (.instantRelease "probe" 2500)
  let deliveryText := match activeLedger.delivery with
    | .idle => "Delivery: idle"
    | .inFlight cid _ => "In-flight: " ++ cid ++ " (awaiting ack)"
    | .uncertain cid _ => "Uncertain: " ++ cid ++ " (locked until sync)"
  <div class="wb-shell">
    <div class="wb-topbar">
      <div class="wb-tabs">
        {[AgentPatch.verified, .buggyRetry, .unhandledV3].map fun p =>
          <div class="wb-tab" data-active={wb.patch == p}>
            <button class="hit-overlay" onClick={Ev.wbPatch p}>{p.title}</button>
            <span class="wb-tab-title">{p.title}</span>
            <span class="status-pill" data-tone={patchTone p}>{p.badge}</span>
          </div>}
      </div>
      <button class="wb-receipt-btn" onClick={Ev.wbProofDrawer}>
        {if wb.proofDrawerOpen then "Hide proof receipt" else "Inspect proof & Wasm receipt"}
      </button>
    </div>

    <div class="wb-columns">
      <div class="wb-left">
        <div class="wb-pane-head">
          <span>{wb.patch.title}</span>
          <span>lakeport check</span>
        </div>
        <div class="wb-code-body">
          {(patchSnippet wb.patch).map fun ln =>
            <div class="wb-code-line">{ln}</div>}
        </div>
        {match wb.patch with
        | .verified =>
          <div class="wb-diag-box" data-tone="ok">
            <span class="wb-diag-title">Lean 4 kernel: 9 theorems verified (0 sorryAx, 0 custom axioms)</span>
            <span class="wb-diag-text">verified_nonreset_conserves, staged_server_blocks_instant, socket_drop_locks_uncertain, and productive_reserve_and_settle all pass. Proof module compiles to 0 B of C/Wasm.</span>
          </div>
        | .buggyRetry =>
          <div class="wb-diag-box" data-tone="err">
            <span class="wb-diag-title">src/Demo/WorkbenchLaws.lean:48:2: error: omega could not prove goal</span>
            <span class="wb-diag-text">Counterexample witness (buggy_retry_loses_conservation): starting from $100.00, clearing delivery on socket drop and retrying yields totalCents = $75.00 (!= $100.00).</span>
            <button class="wb-counterex-btn" onClick={Ev.wbCounterexample}>Run counterexample in live ledger</button>
          </div>
        | .unhandledV3 =>
          <div class="wb-diag-box" data-tone="warn">
            <span class="wb-diag-title">shared/SiteContract/Api.lean:24:2: error: missing cases: Version.v3</span>
            <span class="wb-diag-text">Because clientHandler has no wildcard arm, adding Version.v3 blocks compilation across every un-updated client and server handler before any deploy can occur.</span>
          </div>}
      </div>

      <div class="wb-right">
        <div class="srv-bar">
          <div class="srv-label-row">
            <span>Live Wasm Escrow Checkout</span>
            <span>{deliveryText}</span>
          </div>
          <div class="seg-group">
            {[ServerMode.legacyV1, .stagedDual, .fullV2].map fun m =>
              <button class="seg-btn" data-active={wb.server == m} onClick={Ev.wbServer m}>{m.label}</button>}
          </div>
        </div>

        <div class="ledger-grid">
          <div class="bucket-card">
            <span class="bucket-label">Available</span>
            <span class="bucket-val">{formatUsd activeLedger.available}</span>
          </div>
          <div class="bucket-card">
            <span class="bucket-label">Held in escrow</span>
            <span class="bucket-val">{formatUsd activeLedger.held}</span>
          </div>
          <div class="bucket-card">
            <span class="bucket-label">Released</span>
            <span class="bucket-val">{formatUsd activeLedger.released}</span>
          </div>
        </div>

        <div class="conservation-bar" data-broken={broken}>
          <span>{if broken then "INVARIANT VIOLATED (Patch B)" else "INVARIANT HELD: available + held + released"}</span>
          <span>{formatUsd total ++ " / $100.00"}</span>
        </div>

        <div class="wb-actions">
          <button class="act-btn" onClick={Ev.wbAction "reserve"}>Reserve $25.00</button>
          <button class="act-btn" onClick={Ev.wbAction "settle"}>Settle held</button>
          {if instantAllowed then
            <button class="act-btn-accent" onClick={Ev.wbAction "instant"}>Instant release $25.00 (v2)</button>
           else
            <button class="act-btn-warn" onClick={Ev.wbAction "inject"}>Inject unnegotiated v2 frame</button>}
          <button class="act-btn" onClick={Ev.wbAction "drop"}>Drop socket</button>
          <button class="act-btn" onClick={Ev.wbAction "reconcile"}>Reconcile sync</button>
          <button class="act-btn" onClick={Ev.wbAction "reset"}>Reset</button>
        </div>

        <div class="wire-log">
          <span class="wire-log-title">Wire & capability gate trace (running in app.wasm)</span>
          {wb.logs.map fun item =>
            <div class="wire-row" data-blocked={item.blocked}>
              <div class="wire-row-top">
                <span class="wire-dir">{item.direction}</span>
                <span>{item.summary}</span>
              </div>
              <span class="wire-raw">{"frame: " ++ item.frame}</span>
            </div>}
        </div>
      </div>
    </div>

    {if wb.proofDrawerOpen then
      <div class="receipt-drawer">
        <div class="receipt-col">
          <span class="receipt-heading">Kernel-checked modules ([proof-only, 0 B C])</span>
          <span class="receipt-item">SiteContract/ContractLaws.lean: 16 theorems (codec round-trips + fail-closed CAPS + gate proofs)</span>
          <span class="receipt-item">LakeportMdx/MdxLaws.lean: 6 theorems (SafeSlug character safety + TOC coherence)</span>
          <span class="receipt-item">Demo/WorkbenchLaws.lean: 9 theorems (conservation, socket lock, productive witness, Patch B refutation)</span>
          <span class="receipt-item">SiteLaws.lean: 5 theorems (LawfulUrlCodec round-trip + MemoCell coherence)</span>
        </div>
        <div class="receipt-col">
          <span class="receipt-heading">Honest trust boundary</span>
          <span class="receipt-item">Proved in Lean 4: pure reducers, URL codecs, wire framing, capability gates, and MemoCell coherence (0 sorryAx, 0 native_decide).</span>
          <span class="receipt-item">Trusted computing base (tested, not kernel-proved): Lean C codegen, clang wasm32, boot.mjs / dom-renderer.mjs, and browser/OS primitives.</span>
        </div>
      </div>
     else <span>{""}</span>}
  </div>

/-! ## 2. `<ContractSimulator />` (Embedded in `04-versioned-contracts.mdx`) -/

def contractSimulatorView (sim : ContractSimState) : V :=
  let parsed := simParsedAd sim
  let negVer : String := match parsed >>= negotiateVersion with
    | some .v1 => "lpw1 (Version.v1 baseline)"
    | some .v2 => "lpw2 (Version.v2 negotiated)"
    | none => "none (fail-closed: unknown schema rejected)"
  let frame := simEncodedFrame sim
  let allowed := simPermitted sim
  <div class="widget-card">
    <div class="widget-header">
      <span class="widget-title">Interactive Edge Contract Simulator</span>
      <span class="widget-sub">shared/SiteContract/Api.lean (live in Wasm)</span>
    </div>
    <div class="seg-group">
      {[ServerMode.legacyV1, .stagedDual, .fullV2].map fun m =>
        <button class="seg-btn" data-active={!sim.corruptAd && sim.server == m} onClick={Ev.simServer m}>{m.label}</button>}
      <button class="seg-btn" data-active={sim.corruptAd} onClick={Ev.simCorrupt}>Corrupt CAPS schema v99</button>
    </div>
    <div class="seg-group">
      {[SimCommand.reserve, .milestone, .instant].map fun c =>
        <button class="seg-btn" data-active={sim.cmd == c} onClick={Ev.simCommand c}>{"Command: " ++ c.label}</button>}
    </div>
    <div class="kv-grid">
      <div class="kv-box">
        <span class="kv-key">GET /api/capabilities</span>
        <span class="kv-mono">{" | ".intercalate (simRawAdFields sim)}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">Negotiated version</span>
        <span class="kv-val">{negVer}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">WirePack encoded frame</span>
        <span class="kv-mono">{frame}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">permitsEncodedFrame</span>
        <span class="status-pill" data-tone={if allowed then "ok" else "err"}>
          {if allowed then "TRUE (ADMITTED)" else "FALSE (BLOCKED BY GATE)"}
        </span>
      </div>
    </div>
  </div>

/-! ## 3. `<RolloutTimeline />` (Embedded on `/` and `05-frontend-first-releases.mdx`) -/

def rolloutTimelineView (st : RolloutStage) : V :=
  <div class="widget-card">
    <div class="widget-header">
      <span class="widget-title">Frontend-First Release Scrubber</span>
      <span class="status-pill" data-tone={if st.gateOpen then "ok" else "warn"}>
        {if st.gateOpen then "instant_release: OPEN" else "instant_release: GATED OFF"}
      </span>
    </div>
    <div class="seg-group">
      {RolloutStage.all.map fun item =>
        <button class="seg-btn" data-active={st == item} onClick={Ev.rollout item.index}>{item.shortTitle}</button>}
    </div>
    <h3 class="card-title">{st.headline}</h3>
    <div class="kv-grid">
      <div class="kv-box">
        <span class="kv-key">Backend advertisement</span>
        <span class="kv-mono">{st.serverAdSummary}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">Older cached tab</span>
        <span class="kv-val">{st.cachedOldClientBehavior}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">Newly shipped Lakeport client</span>
        <span class="kv-val">{st.newClientBehavior}</span>
      </div>
    </div>
  </div>

/-! ## 4. `<DeadCodeExplorer />` (Embedded on `/ecosystem` and `11-reservoir-and-bundle-size.mdx`) -/

def deadCodeExplorerView (d : DceState) : V :=
  let m := computeDceMetrics d
  <div class="widget-card">
    <div class="widget-header">
      <span class="widget-title">Reservoir Dead-Code & Proof Erasure Calculator</span>
      <span class="widget-sub">Prop erasure + [proof-only, 0 B C] + wasm-ld --gc-sections</span>
    </div>
    <div class="seg-group">
      <button class="seg-btn" data-active={true} onClick={Ev.dceProfile d.profile}>site-contract (required)</button>
      <button class="seg-btn" data-active={true} onClick={Ev.dceProfile d.profile}>lakeport-mdx (required)</button>
      <button class="seg-btn" data-active={d.includeLedgerPkg} onClick={Ev.dceTogglePkg "ledger"}>
        {if d.includeLedgerPkg then "+ lakeport-ledger (on)" else "+ lakeport-ledger (off)"}
      </button>
      <button class="seg-btn" data-active={d.includeChartsPkg} onClick={Ev.dceTogglePkg "charts"}>
        {if d.includeChartsPkg then "+ lakeport-charts (unused)" else "+ lakeport-charts (off)"}
      </button>
    </div>
    <div class="seg-group">
      {[UsageProfile.fullDocsSite, .slugOnlyUtility, .v1RetiredClean].map fun p =>
        <button class="seg-btn" data-active={d.profile == p} onClick={Ev.dceProfile p}>{p.label}</button>}
    </div>
    <div class="kv-grid">
      <div class="kv-box">
        <span class="kv-key">Workspace Lean + proof lines</span>
        <span class="kv-val">{toString m.totalSourceLines ++ " lines (" ++ toString m.theoremProofLines ++ " in proofs)"}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">Proof runtime cost</span>
        <span class="kv-mono">{toString m.proofRuntimeBytes ++ " B in C & Wasm"}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">Reachable vs dropped decls</span>
        <span class="kv-val">{toString m.reachableDecls ++ " linked / " ++ toString m.droppedDecls ++ " stripped"}</span>
      </div>
      <div class="kv-box">
        <span class="kv-key">Resulting gzipped Wasm</span>
        <span class="kv-mono">{"~" ++ toString m.gzipWasmKb ++ " KB"}</span>
      </div>
    </div>
  </div>

/-- Build `LakeportMdx.RenderHooks` wiring internal links, clipboard copy, and embedded widgets. -/
def mdxHooks (s : AppState) : RenderHooks UiEvent Nat where
  onNavigate := Ev.nav
  onCopy := Ev.copy
  copiedKey := s.copiedKey
  renderWidget := fun name _ =>
    if name == "ContractSimulator" then contractSimulatorView s.contractSim
    else if name == "RolloutTimeline" then rolloutTimelineView s.rolloutStage
    else if name == "DeadCodeExplorer" then deadCodeExplorerView s.dce
    else <span>{""}</span>

end Site.Widgets
