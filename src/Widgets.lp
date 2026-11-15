import LakeportMdx
import SiteContract.Versions
import SiteContract.Api
import State
import Events
import Brand
set_option synthInstance.maxSize 4096
/-!
# `Site.Widgets`: Live WebAssembly Checkout Simulator, Rollout Track & Docs Widgets

Pure `.lp` TSX components backed by `Site.Demo` and `Site.Contract`:
- `workbenchVesselView`: Homepage flaky-Wi-Fi checkout simulator
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

def amberBtn (label : String) (ev : UiEvent) : V :=
  <div class="btn-amber">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="btn-label">{label}</span>
  </div>

def inlineLinkBtn (label : String) (ev : UiEvent) : V :=
  <div class="inline-link">
    <button class="hit-overlay" onClick={ev}>{label}</button>
    <span class="inline-link-text">{label}</span>
  </div>

/-! ## 1. Homepage Flaky-Wi-Fi Checkout Simulator -/

private def codeLine (text : String) (tone : String := "plain") : V :=
  <div class="wb-code-line" data-tone={tone}>
    <span class="wb-code-src">{text}</span>
  </div>

private def buggyDraftSourceView : V :=
  <div class="wb-code-body">
    {codeLine "def stepBuggyAgentRetry (l : Ledger) : Ledger :="}
    {codeLine "  let afterSend :="}
    {codeLine "    { l with available := l.available - 2500,"}
    {codeLine "             held := l.held + 2500,"}
    {codeLine "             delivery := .inFlight \"pay_1\" 2500 }"}
    {codeLine "  let afterTimeoutUnlocked := { afterSend with delivery := .idle }" "fault"}
    {codeLine "  { afterTimeoutUnlocked with available := afterTimeoutUnlocked.available - 2500," "fault"}
    {codeLine "                              delivery := .inFlight \"pay_2\" 2500 }" "fault"}
  </div>

private def checkedVersionSourceView : V :=
  <div class="wb-code-body">
    {codeLine "def stepVerifiedLedger (srv : ServerMode) (l : Ledger) :="}
    {codeLine "  | .dropSocket =>"}
    {codeLine "    match l.delivery with"}
    {codeLine "    | .inFlight cid c => ({ l with delivery := .uncertain cid c }, netLog)" "guard"}
    {codeLine "    | _ => (l, netLog)"}
    {codeLine "  | .reserve25 =>"}
    {codeLine "    if l.delivery == .idle && 2500 <= l.available then" "guard"}
    {codeLine "      debitOnce l else keepLocked l" "guard"}
  </div>

def workbenchVesselView (wb : WorkbenchState) : V :=
  let out := runCheckout wb.mode wb.netRun
  let outcomeTone :=
    if wb.netRun == .idle then "idle"
    else if out.overcharged then "fault"
    else "ok"
  <div class="wb-wrap">
    <div class="wb-vessel">
      <div class="wb-pane-code">
        <div class="wb-pane-bar">
          <div class="wb-tabs">
            <button class="wb-tab" data-active={wb.mode == .agentDraft} onClick={Ev.wbMode .agentDraft}>
              1. Agent's first draft (tests pass)
            </button>
            <button class="wb-tab" data-active={wb.mode == .lakeportFixed} onClick={Ev.wbMode .lakeportFixed}>
              2. After Lakeport's compiler check
            </button>
          </div>
        </div>

        <p class="wb-explain">
          {if wb.mode == .agentDraft then
            "You asked your coding agent to auto-retry a $25.00 checkout when Wi-Fi drops. Its unit test runs on a healthy connection and passes, so a normal CI pipeline turns green. On a real timeout, the highlighted retry block unlocks the payment early."
           else
            "Lakeport's compiler rejected the first draft because unlocking an in-flight payment broke your no-double-charge rule. With that compiler error, the agent kept pay_1 locked as uncertain until the server confirms what happened."}
        </p>

        {if wb.mode == .agentDraft then buggyDraftSourceView else checkedVersionSourceView}

        <div class="wb-code-foot">
          {if wb.mode == .agentDraft then
            evidenceItem .failed "Rejected by lakeport check: retry path can bill $25.00 twice" false
           else
            evidenceItem .proved "Accepted by lakeport check: customer is billed at most $25.00" false}
        </div>
      </div>

      <div class="wb-pane-state">
        <div class="wb-pane-bar">
          <span class="wb-pane-title">$25.00 Checkout Simulator</span>
          <span class="wb-file-path">Live WebAssembly</span>
        </div>

        <div class="wb-state-body">
          <div class="wb-wallet-grid">
            <div class="wb-wallet-card">
              <span class="wb-wallet-label">Customer wallet</span>
              <span class="wb-total-num" data-violated={out.overcharged}>{formatUsd out.walletCents}</span>
              <span class="wb-wallet-note">Started with $100.00</span>
            </div>

            <div class="wb-wallet-card">
              <span class="wb-wallet-label">Charged for $25.00 item</span>
              <span class="wb-charged-num" data-violated={out.overcharged} data-ok={wb.netRun != .idle && !out.overcharged}>
                {formatUsd out.chargedCents}
              </span>
              <span class="wb-wallet-note">
                {if wb.netRun == .idle then "Click a Wi-Fi test below"
                 else if out.overcharged then "Billed twice for one item"
                 else "Billed once as expected"}
              </span>
            </div>
          </div>

          <div class="wb-primary-actions">
            {amberBtn "Pay $25 on flaky Wi-Fi" (Ev.wbRun .flakyWifi)}
            <button class="wb-secondary-btn" data-active={wb.netRun == .normalWifi} onClick={Ev.wbRun .normalWifi}>
              Pay $25 on normal Wi-Fi
            </button>
            {if wb.netRun != .idle then
              <button class="wb-reset-btn" onClick={Ev.wbRun .idle}>Reset</button>
             else <span>{""}</span>}
          </div>

          <div class="wb-outcome-box" data-state={outcomeTone}>
            <p class="wb-outcome-head">{out.headline}</p>
            <div class="wb-outcome-steps">
              <p class="wb-outcome-step">{out.step1}</p>
              <p class="wb-outcome-step">{out.step2}</p>
              {if out.step3.isEmpty then <span>{""}</span>
               else <p class="wb-outcome-step">{out.step3}</p>}
            </div>
            {if wb.mode == .agentDraft && wb.netRun == .flakyWifi then
              <div class="wb-fix-cta">
                <button class="wb-fix-btn" onClick={Ev.wbSeeCheckedFix}>
                  See Lakeport's checked fix on flaky Wi-Fi →
                </button>
              </div>
             else <span>{""}</span>}
          </div>
        </div>
      </div>
    </div>

    <div class="wb-disclosures">
      <div class="wb-disclosure-bar">
        <button class="wb-disclosure-btn" data-open={wb.ruleOpen} onClick={Ev.wbToggleRule}>
          {if wb.ruleOpen then "Hide the Lean rule the agent wrote"
           else "Curious what the proof looks like? Show the rule the agent wrote"}
        </button>
      </div>

      {if wb.ruleOpen then
        <div class="wb-drawer">
          <div class="wb-drawer-col">
            <span class="wb-drawer-title">What you tell your coding agent</span>
            <p class="wb-rule-quote">
              "Never charge a customer more than $25.00 for a single $25.00 checkout, even when Wi-Fi drops mid-request."
            </p>
            <p class="wb-rule-note">
              You do not have to write Lean proof syntax yourself. Your agent translates that sentence into the rule on the right, and Lakeport refuses to build if the rule and the code disagree.
            </p>
          </div>
          <div class="wb-drawer-col">
            <span class="wb-drawer-title">What your agent maintains in WorkbenchLaws.lean</span>
            <div class="theorem-pre">
              <span class="syn-kw">{"theorem "}</span>
              <span class="syn-fn">lakeportFixed_never_overcharges</span>
              <span>{" (net : NetworkRun) :
  let out := runCheckout .lakeportFixed net
  "}</span>
              <span class="syn-ty">{"out.overcharged = false ∧ out.chargedCents ≤ 2500"}</span>
            </div>
            {evidenceItem .proved "Checked across every NetworkRun with 0 custom axioms" false}
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
      <span class="widget-title">Client Contract & Capability Simulator</span>
      <span class="widget-sub">shared/SiteContract/Api.lean, live in Wasm</span>
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
          evidenceItem .proved "true (frame permitted by client gate)"
         else
          evidenceItem .failed "false (blocked in client before socket write)"}
      </div>
    </div>
  </div>

/-! ## 3. `<RolloutTimeline />` (Embedded on `/` and `05-frontend-first-releases.mdx`) -/

def rolloutTimelineView (st : RolloutStage) : V :=
  <div class="rollout-track-box">
    <div class="rollout-stops">
      {RolloutStage.all.map fun item =>
        <div class="rollout-stop" data-active={st == item}>
          <button class="hit-overlay" onClick={Ev.rollout item.index}>{item.stageTag ++ " " ++ item.shortTitle}</button>
          <span class="rollout-stop-num">{item.stageTag}</span>
          <span class="rollout-stop-title">{item.shortTitle}</span>
        </div>}
    </div>

    <p class="rollout-stage-headline">{st.headline}</p>

    <div class="spec-rows">
      <div class="spec-row">
        <span class="spec-key">Your backend</span>
        <span class="spec-mono">{st.serverAdSummary}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Open older tab</span>
        <span class="spec-val">{st.cachedOldClientBehavior}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Updated client</span>
        <span class="spec-val">{st.newClientBehavior}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">v2 feature gate</span>
        {if st.gateOpen then
          evidenceItem .proved st.admissionSummary false
         else
          evidenceItem .trusted st.admissionSummary false}
      </div>
    </div>
  </div>

/-! ## 4. `<DeadCodeExplorer />` (Embedded on `/ecosystem` and `11-reservoir-and-bundle-size.mdx`) -/

def deadCodeExplorerView (d : DceState) : V :=
  let m := computeDceMetrics d
  <div class="widget-card">
    <div class="widget-header">
      <span class="widget-title">Package Size & Proof-Stripping Explorer</span>
      <span class="widget-sub">Proofs erase to 0 B, unused code drops at link time</span>
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
        <span class="spec-key">Source & proof lines</span>
        <span class="spec-val">{toString m.totalSourceLines ++ " lines (" ++ toString m.theoremProofLines ++ " lines of proofs)"}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Proof bytes in output</span>
        {evidenceItem .proved (toString m.proofRuntimeBytes ++ " bytes in C and WebAssembly")}
      </div>
      <div class="spec-row">
        <span class="spec-key">Compiled functions</span>
        <span class="spec-mono">{toString m.reachableDecls ++ " linked, " ++ toString m.droppedDecls ++ " stripped"}</span>
      </div>
      <div class="spec-row">
        <span class="spec-key">Estimated slice</span>
        <span class="spec-mono">{"~" ++ toString m.modeledSliceKb ++ " KB slice (full lakeport-www site: 459 KB gzipped)"}</span>
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
