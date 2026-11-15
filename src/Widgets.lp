import LakeportMdx
import SiteContract.Versions
import SiteContract.Api
import State
import Events
import Brand
set_option synthInstance.maxSize 4096
/-!
# `Site.Widgets` — Live WebAssembly Escrow Vessel, Rollout Track & Docs Simulators

Pure `.lp` TSX components backed by `Site.Demo` and `Site.Contract`:
- `workbenchVesselView`: Homepage "One retry. $25 missing." live Wasm demonstration
- `contractSimulatorView`: `<ContractSimulator />` embedded inside `04-versioned-contracts.mdx`
- `rolloutTimelineView`: `<RolloutTimeline />` embedded on `/` and `05-frontend-first-releases.mdx`
- `deadCodeExplorerView`: `<DeadCodeExplorer />` embedded on `/ecosystem` and `11-reservoir-and-bundle-size.mdx`
-/
namespace Site.Widgets
open LakeportStyle LakeportMdx Site Site.Contract Site.Demo Site.Brand

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

namespace Icon

def pathLine (d : String) : V :=
  <span data-lp-svg-shape="path" data-lp-d={d} data-lp-stroke="currentColor" data-lp-fill="none" data-lp-stroke-width="1.8" />

def ring (cx cy r : String) : V :=
  <span data-lp-svg-shape="circle" data-lp-cx={cx} data-lp-cy={cy} data-lp-r={r} data-lp-stroke="currentColor" data-lp-fill="none" data-lp-stroke-width="1.8" />

def sun : List V := [ring "12" "12" "4", pathLine "M12 2.5V5M12 19V21.5M2.5 12H5M19 12H21.5M5.3 5.3L7 7M17 17L18.7 18.7M5.3 18.7L7 17M17 7L18.7 5.3"]
def moon : List V := [pathLine "M20 14.2C18.9 14.8 17.6 15.1 16.3 15.1C12.2 15.1 8.9 11.8 8.9 7.7C8.9 6.4 9.2 5.1 9.8 4C6.2 5 3.5 8.2 3.5 12.1C3.5 16.7 7.3 20.5 11.9 20.5C15.8 20.5 19 17.8 20 14.2Z"]
def autoHalf : List V := [ring "12" "12" "7.5", pathLine "M12 4.5V19.5"]
def menu : List V := [pathLine "M4 7H20M4 12H20M4 17H20"]
def close : List V := [pathLine "M6 6L18 18M18 6L6 18"]
def search : List V := [ring "10.5" "10.5" "6.2", pathLine "M15.3 15.3L20.2 20.2"]

end Icon

def svg (size : String) (shapes : List V) : V :=
  <span class="svg-box" data-size={size} data-lp-svg="0 0 24 24">{shapes}</span>

def primaryBtn (label : String) (ev : UiEvent) : V :=
  <div class="btn-primary">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="btn-label">{label}</span>
  </div>

def beaconBtn (label : String) (ev : UiEvent) : V :=
  <div class="btn-beacon">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="btn-label">{label}</span>
  </div>

def inlineLinkBtn (label : String) (ev : UiEvent) : V :=
  <div class="inline-link">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="inline-link-text">{label}</span>
  </div>

/-! ## 1. Homepage Live Wasm Demonstration ("One retry. $25 missing.") -/

private def codeLine (num text : String) (tone : String := "plain") : V :=
  <div class="wb-code-line" data-tone={tone}>
    <span class="wb-ln">{num}</span>
    <span class="wb-code-src">{text}</span>
  </div>

private def buggyPatchSourceView : V :=
  <div class="wb-code-body">
    {codeLine "01" "def stepBuggyAgentRetry (l : Ledger) : Ledger :="}
    {codeLine "02" "  let afterReserve :="}
    {codeLine "03" "    { l with available := l.available - 2500,"}
    {codeLine "04" "             held := l.held + 2500,"}
    {codeLine "05" "             delivery := .inFlight \"cid-1\" 2500 }"}
    {codeLine "06" "  -- Socket closes before ACK; agent clears flight lock:" "comment"}
    {codeLine "07" "  let afterDrop := { afterReserve with delivery := .idle }" "fault"}
    {codeLine "08" "  -- Retry debits $25.00 a second time without crediting held:" "comment"}
    {codeLine "09" "  { afterDrop with available := afterDrop.available - 2500," "fault"}
    {codeLine "10" "                   delivery := .inFlight \"cid-2\" 2500 }" "fault"}
  </div>

private def checkedReducerSourceView : V :=
  <div class="wb-code-body">
    {codeLine "01" "def stepVerifiedLedger (srv : ServerMode) (l : Ledger) :="}
    {codeLine "02" "  | .dropSocket =>"}
    {codeLine "03" "    match l.delivery with"}
    {codeLine "04" "    | .inFlight cid c => ({ l with delivery := .uncertain cid c }, netLog)" "guard"}
    {codeLine "05" "    | _ => (l, netLog)"}
    {codeLine "06" "  | .reserve25 =>"}
    {codeLine "07" "    if l.delivery == .idle && 2500 <= l.available then" "guard"}
    {codeLine "08" "      ({ l with available := l.available - 2500,"}
    {codeLine "09" "                held := l.held + 2500, delivery := .inFlight cid 2500 }, outLog)"}
    {codeLine "10" "    else (l, holdBlockedLog) -- duplicate retry rejected until sync"}
  </div>

def workbenchVesselView (wb : WorkbenchState) : V :=
  let isBuggyTab := wb.patch == .buggyRetry
  let shown : Ledger :=
    match wb.patch, wb.buggyPreview with
    | .buggyRetry, some broken => broken
    | _, _ => wb.ledger
  let violated := isBuggyTab && wb.buggyPreview.isSome
  let missingCents := if shown.totalCents < 10000 then 10000 - shown.totalCents else 0
  let flightLabel :=
    match shown.delivery with
    | .idle => "delivery: .idle"
    | .inFlight cid _ => "delivery: .inFlight (" ++ cid ++ ")"
    | .uncertain cid _ => "delivery: .uncertain (" ++ cid ++ " locked)"
  <div class="wb-wrap">
    <div class="wb-vessel">
      <div class="wb-pane-code">
        <div class="wb-pane-bar">
          <div class="wb-tabs">
            <button class="wb-tab" data-active={isBuggyTab} onClick={Ev.wbPatch .buggyRetry}>
              {"Agent's patch"}
            </button>
            <button class="wb-tab" data-active={!isBuggyTab} onClick={Ev.wbPatch .verified}>
              {"Checked reducer"}
            </button>
          </div>
          <span class="wb-file-path">src/Demo/Workbench.lean</span>
        </div>

        {if isBuggyTab then buggyPatchSourceView else checkedReducerSourceView}

        <div class="wb-code-foot">
          {if isBuggyTab then
            evidenceItem .proved "buggy_retry_loses_conservation (refuted in Lean)"
           else if wb.checkedCompared then
            evidenceItem .proved "checked_retry_comparison_conserves (0 custom axioms)"
           else
            evidenceItem .proved "verified_nonreset_conserves (0 custom axioms)"}
        </div>
      </div>

      <div class="wb-pane-state">
        <div class="wb-pane-bar">
          <span class="wb-pane-kicker">LIVE WASM ESCROW</span>
          <span class="wb-flight-tag" data-locked={shown.delivery != .idle}>{flightLabel}</span>
        </div>

        <div class="wb-state-body">
          <div class="wb-total-row">
            <span class="wb-total-num" data-violated={violated}>{formatUsd shown.totalCents}</span>
            <span class="wb-total-target">
              {if violated then "of $100.00 · $25.00 missing" else "of $100.00 conserved"}
            </span>
          </div>

          <div class="wb-bar-track">
            <span class="wb-seg wb-seg-avail" data-q={centsQuarterTag shown.available} />
            <span class="wb-seg wb-seg-held" data-q={centsQuarterTag shown.held} />
            <span class="wb-seg wb-seg-rel" data-q={centsQuarterTag shown.released} />
            <span class="wb-seg wb-seg-missing" data-q={centsQuarterTag missingCents} />
          </div>

          <div class="wb-buckets">
            <div class="wb-bucket">
              <span class="wb-bucket-key">
                <span class="wb-swatch" data-kind="avail" />
                <span>Available</span>
              </span>
              <span class="wb-bucket-val">{formatUsd shown.available}</span>
            </div>
            <div class="wb-bucket">
              <span class="wb-bucket-key">
                <span class="wb-swatch" data-kind="held" />
                <span>Held</span>
              </span>
              <span class="wb-bucket-val">{formatUsd shown.held}</span>
            </div>
            <div class="wb-bucket">
              <span class="wb-bucket-key">
                <span class="wb-swatch" data-kind="rel" />
                <span>Released</span>
              </span>
              <span class="wb-bucket-val">{formatUsd shown.released}</span>
            </div>
          </div>

          <div class="wb-primary-actions">
            {beaconBtn "Run faulty retry" Ev.wbCounterexample}
            <button class="wb-secondary-btn" onClick={Ev.wbCompareChecked}>
              Compare checked reducer
            </button>
          </div>

          <div class="wb-step-strip">
            <span class="wb-step-label">Step reducer:</span>
            <button class="wb-step-btn" onClick={Ev.wbAction "reserve"}>Reserve $25.00</button>
            <button class="wb-step-btn" onClick={Ev.wbAction "drop"}>Drop socket</button>
            <button class="wb-step-btn" onClick={Ev.wbAction "settle"}>Settle held</button>
            <button class="wb-step-btn" onClick={Ev.wbAction "reconcile"}>Reconcile sync</button>
            <button class="wb-step-btn" onClick={Ev.wbAction "reset"}>Reset</button>
          </div>
        </div>

        <div class="wb-verdict-bar" data-violated={violated}>
          {if violated then
            evidenceItem .failed "LedgerConserved ($100.00 → $75.00 after socket retry)"
           else if wb.checkedCompared then
            evidenceItem .proved "Duplicate retry rejected while cid-1 awaits reconciliation"
           else
            evidenceItem .proved "LedgerConserved ($100.00 / $100.00 across stepVerifiedLedger)"}
        </div>
      </div>
    </div>

    <div class="wb-disclosures">
      <div class="wb-disclosure-bar">
        <button class="wb-disclosure-btn" data-open={wb.proofDrawerOpen} onClick={Ev.wbProofDrawer}>
          {if wb.proofDrawerOpen then "− Hide evidence & axioms" else "+ Inspect evidence & axioms"}
        </button>
        <button class="wb-disclosure-btn" data-open={wb.contractExplorerOpen} onClick={Ev.wbContractExplorer}>
          {if wb.contractExplorerOpen then "− Hide wire & capability gates" else "+ Explore wire & capability gates"}
        </button>
      </div>

      {if wb.proofDrawerOpen then
        <div class="wb-drawer">
          <div class="wb-drawer-col">
            <span class="wb-drawer-title">Kernel-checked modules (39 theorems · 0 B emitted C/Wasm)</span>
            {evidenceItem .proved "SiteContract/ContractLaws.lean · 16 theorems (wire round-trip + gate)"}
            {evidenceItem .proved "Demo/WorkbenchLaws.lean · 12 theorems (conservation + retry refutation)"}
            {evidenceItem .proved "LakeportMdx/MdxLaws.lean · 6 theorems (SafeSlug + TOC coherence)"}
            {evidenceItem .proved "SiteLaws.lean · 5 theorems (URL round-trip + MemoCell coherence)"}
          </div>
          <div class="wb-drawer-col">
            <span class="wb-drawer-title">Explicit trust & measurement boundary</span>
            {evidenceItem .trusted "Lean 4.35 kernel, C codegen, and clang wasm32 toolchain" false}
            {evidenceItem .trusted "Host JS shim (boot.mjs, dom-renderer.mjs) and browser DOM/WebSocket APIs" false}
            {evidenceItem .unknown "Live network latency and third-party edge availability at runtime" false}
          </div>
        </div>
       else <span>{""}</span>}

      {if wb.contractExplorerOpen then
        <div class="wb-drawer wb-drawer-stack">
          <div class="wb-gate-controls">
            <div class="wb-gate-group">
              <span class="wb-drawer-title">Backend capability advertisement</span>
              <div class="seg-group">
                {[ServerMode.legacyV1, .stagedDual, .fullV2].map fun m =>
                  <button class="seg-btn" data-active={wb.server == m} onClick={Ev.wbServer m}>{m.label}</button>}
              </div>
            </div>
            <div class="wb-gate-group">
              <span class="wb-drawer-title">Capability-gated v2 frames</span>
              <div class="seg-group">
                <button class="seg-btn" data-active={false} onClick={Ev.wbAction "instant"}>Instant release $25.00</button>
                <button class="seg-btn" data-active={false} onClick={Ev.wbAction "inject"}>Inject unnegotiated v2 frame</button>
              </div>
            </div>
          </div>

          <div class="wire-log">
            <span class="wb-drawer-title">Recent frames evaluated by app_lp2.wasm</span>
            {wb.logs.map fun item =>
              <div class="wire-row" data-blocked={item.blocked}>
                <span class="wire-dir">{item.direction}</span>
                <span class="wire-summary">{item.summary}</span>
                <span class="wire-raw">{item.frame}</span>
              </div>}
          </div>
        </div>
       else <span>{""}</span>}
    </div>
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
      <span class="widget-title">Edge Contract & Gate Simulator</span>
      <span class="widget-sub">shared/SiteContract/Api.lean · live in Wasm</span>
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
    <div class="spec-rows">
      <div class="spec-row">
        <span class="spec-key">GET /api/capabilities</span>
        <span class="spec-mono">{" | ".intercalate (simRawAdFields sim)}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Negotiated version</span>
        <span class="spec-val">{negVer}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Encoded wire frame</span>
        <span class="spec-mono">{frame}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">permitsEncodedFrame</span>
        {if allowed then
          evidenceItem .proved "true (frame admitted by Gate)"
         else
          evidenceItem .failed "false (blocked before socket write)"}
      </div>
    </div>
  </div>

/-! ## 3. `<RolloutTimeline />` (Embedded on `/` and `05-frontend-first-releases.mdx`) -/

def rolloutTimelineView (st : RolloutStage) : V :=
  <div class="rollout-track-box">
    <div class="rollout-stops">
      {RolloutStage.all.map fun item =>
        <div class="rollout-stop" data-active={st == item}>
          <button class="hit-overlay" onClick={Ev.rollout item.index}>{item.stepNumber ++ " " ++ item.shortTitle}</button>
          <span class="rollout-stop-num">{item.stepNumber}</span>
          <span class="rollout-stop-title">{item.shortTitle}</span>
        </div>}
    </div>

    <p class="rollout-stage-headline">{st.headline}</p>

    <div class="spec-rows">
      <div class="spec-row">
        <span class="spec-key">Server advertises</span>
        <span class="spec-mono">{st.serverAdSummary}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Cached old tab</span>
        <span class="spec-val">{st.cachedOldClientBehavior}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">New client</span>
        <span class="spec-val">{st.newClientBehavior}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Gate admission</span>
        {if st.gateOpen then
          evidenceItem .proved st.admissionSummary
         else
          evidenceItem .trusted st.admissionSummary}
      </div>
    </div>
  </div>

/-! ## 4. `<DeadCodeExplorer />` (Embedded on `/ecosystem` and `11-reservoir-and-bundle-size.mdx`) -/

def deadCodeExplorerView (d : DceState) : V :=
  let m := computeDceMetrics d
  <div class="widget-card">
    <div class="widget-header">
      <span class="widget-title">Illustrative Reachability & Proof-Erasure Model</span>
      <span class="widget-sub">Prop erasure + wasm-ld --gc-sections</span>
    </div>
    <div class="seg-group">
      <button class="seg-btn" data-active={d.includeLedgerPkg} onClick={Ev.dceTogglePkg "ledger"}>
        {if d.includeLedgerPkg then "lakeport-ledger: imported" else "lakeport-ledger: omitted"}
      </button>
      <button class="seg-btn" data-active={d.includeChartsPkg} onClick={Ev.dceTogglePkg "charts"}>
        {if d.includeChartsPkg then "lakeport-charts: imported (0 calls)" else "lakeport-charts: omitted"}
      </button>
    </div>
    <div class="seg-group">
      {[UsageProfile.fullDocsSite, .slugOnlyUtility, .v1RetiredClean].map fun p =>
        <button class="seg-btn" data-active={d.profile == p} onClick={Ev.dceProfile p}>{p.label}</button>}
    </div>
    <div class="spec-rows">
      <div class="spec-row">
        <span class="spec-key">Workspace source & proofs</span>
        <span class="spec-val">{toString m.totalSourceLines ++ " lines (" ++ toString m.theoremProofLines ++ " in theorems)"}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Emitted proof bytes</span>
        {evidenceItem .proved (toString m.proofRuntimeBytes ++ " B in C & Wasm (dce_proof_bytes_always_zero)")}
      </div>
      <div class="spec-row">
        <span class="spec-key">Reachable declarations</span>
        <span class="spec-mono">{toString m.reachableDecls ++ " linked · " ++ toString m.droppedDecls ++ " stripped"}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Modeled feature slice</span>
        <span class="spec-mono">{"~" ++ toString m.modeledSliceKb ++ " KB modeled slice (full lakeport-www app_lp2.wasm: 463 KB gzipped)"}</span>
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
