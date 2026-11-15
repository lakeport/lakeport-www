import SiteContract.Versions
import SiteContract.Wire
import SiteContract.Api
/-!
# `Site.Demo` : Checkout Retry Demo, Rollout Scrubber & Reachability Model

Pure Lean domain logic compiled to WebAssembly for:
1. Homepage flaky-Wi-Fi checkout simulator (`CheckoutMode`, `NetworkRun`, `runCheckout`)
2. Underlying escrow & capability state machine (`Ledger`, `stepVerifiedLedger`)
3. Docs `<ContractSimulator />`, `<RolloutTimeline />`, and `<DeadCodeExplorer />`
-/
namespace Site.Demo
open Site.Contract Site.Contract.Wire

/-! ## 1. Server Capability Profiles & Verified Ledger Core -/

inductive ServerMode where
  | legacyV1
  | stagedDual
  | fullV2
  deriving DecidableEq, Repr, Inhabited

namespace ServerMode

def slug : ServerMode → String
  | .legacyV1 => "v1"
  | .stagedDual => "v2-staged"
  | .fullV2 => "v2-full"

def parse : String → ServerMode
  | "v1" => .legacyV1
  | "v2-staged" => .stagedDual
  | _ => .fullV2

def label : ServerMode → String
  | .legacyV1 => "v1 only"
  | .stagedDual => "v1 and v2 (feature off)"
  | .fullV2 => "v1 and v2 (feature on)"

def advertisement : ServerMode → Advertisement
  | .legacyV1 => legacyServerAd
  | .stagedDual => dualServerBaselineAd
  | .fullV2 => fullV2ServerAd

end ServerMode

inductive DeliveryStatus where
  | idle
  | inFlight (cid : String) (cents : Nat)
  | uncertain (cid : String) (cents : Nat)
  deriving DecidableEq, Repr, Inhabited

structure WireLogEntry where
  seq : Nat
  direction : String
  summary : String
  frame : String
  blocked : Bool := false
  deriving DecidableEq, Repr, Inhabited

structure Ledger where
  available : Nat := 10000
  held : Nat := 0
  released : Nat := 0
  delivery : DeliveryStatus := .idle
  nextCid : Nat := 1
  deriving DecidableEq, Repr, Inhabited

def Ledger.totalCents (l : Ledger) : Nat :=
  l.available + l.held + l.released

def LedgerConserved (l : Ledger) (initial : Nat) : Prop :=
  l.totalCents = initial ∧
  match l.delivery with
  | .idle => True
  | .inFlight _ c => c ≤ l.held
  | .uncertain _ c => c ≤ l.held

inductive LedgerAction where
  | reserve25
  | settleMilestone
  | instantRelease25
  | dropSocket
  | reconcileReconnect
  | injectUnnegotiated
  | reset
  deriving DecidableEq, Repr

def stepVerifiedLedger (srv : ServerMode) (l : Ledger) : LedgerAction → Ledger × WireLogEntry
  | .reserve25 =>
    let cid := "pay_" ++ Nat.repr l.nextCid
    let ad := srv.advertisement
    if l.delivery == .idle && 2500 <= l.available then
      let frame := match negotiateVersion ad with
        | some .v2 => V2.encodeReq (.reserve cid 2500)
        | _ => V1.encodeReq (.reserve cid 2500)
      ({ l with
          available := l.available - 2500
          held := l.held + 2500
          delivery := .inFlight cid 2500
          nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "SEND", summary := "Sent $25.00 payment request", frame })
    else
      (l, { seq := l.nextCid, direction := "LOCK",
            summary := "Duplicate retry skipped while original payment awaits confirmation",
            frame := "noop", blocked := true })
  | .settleMilestone =>
    let cid := "pay_" ++ Nat.repr l.nextCid
    if l.held > 0 then
      let frame := V2.encodeResp (.ack cid l.available 0 (l.released + l.held) "rcpt-ok")
      ({ l with
          held := 0
          released := l.released + l.held
          delivery := .idle
          nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "ACK", summary := "Confirmed $25.00 payment once", frame })
    else
      (l, { seq := l.nextCid, direction := "HOLD", summary := "No pending payment", frame := "noop", blocked := true })
  | .instantRelease25 =>
    let cid := "pay_" ++ Nat.repr l.nextCid
    let cmd := V2.ClientFrame.instantRelease cid 2500
    if permitsV2Command (some srv.advertisement) cmd then
      if l.delivery == .idle && 2500 <= l.available then
        let frame := V2.encodeReq cmd
        ({ l with
            available := l.available - 2500
            released := l.released + 2500
            nextCid := l.nextCid + 1 },
         { seq := l.nextCid, direction := "ACK", summary := "Processed instant v2 payment ($25.00)", frame })
      else
        (l, { seq := l.nextCid, direction := "LOCK", summary := "Payment already in progress", frame := "noop", blocked := true })
    else
      let raw := V2.encodeReq cmd
      (l, { seq := l.nextCid, direction := "GATE",
            summary := "Blocked locally because server has not enabled instant_release",
            frame := raw, blocked := true })
  | .dropSocket =>
    match l.delivery with
    | .inFlight cid cents =>
      ({ l with delivery := .uncertain cid cents },
       { seq := l.nextCid, direction := "DROP",
         summary := "Wi-Fi dropped before receipt; kept " ++ cid ++ " locked",
         frame := "wsClose(1006)" })
    | .uncertain cid _ =>
      (l, { seq := l.nextCid, direction := "DROP", summary := cid ++ " remains locked", frame := "wsClose(1006)" })
    | .idle =>
      (l, { seq := l.nextCid, direction := "DROP", summary := "Connection dropped while idle", frame := "wsClose(1006)" })
  | .reconcileReconnect =>
    match l.delivery with
    | .uncertain cid _ =>
      let frame := V2.encodeResp (.ack cid l.available l.held l.released ("reconciled-" ++ cid))
      ({ l with delivery := .idle, nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "SYNC", summary := "Server confirmed original " ++ cid, frame })
    | .inFlight cid _ =>
      ({ l with delivery := .idle, nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "ACK", summary := "Confirmed " ++ cid, frame := "ack(" ++ cid ++ ")" })
    | .idle =>
      (l, { seq := l.nextCid, direction := "SYNC", summary := "Synced capabilities", frame := "CAPS/1" })
  | .injectUnnegotiated =>
    let cid := "adv_" ++ Nat.repr l.nextCid
    let forged := V2.encodeReq (.instantRelease cid 2500)
    if permitsEncodedFrame (some srv.advertisement) forged then
      if l.delivery == .idle && 2500 <= l.available then
        ({ l with available := l.available - 2500, released := l.released + 2500, nextCid := l.nextCid + 1 },
         { seq := l.nextCid, direction := "SEND", summary := "Server supports feature; request sent", frame := forged })
      else
        (l, { seq := l.nextCid, direction := "HOLD", summary := "Skipped by balance lock", frame := forged, blocked := true })
    else
      (l, { seq := l.nextCid, direction := "BLOCKED",
            summary := "permitsEncodedFrame rejected unnegotiated v2 frame before socket write",
            frame := forged, blocked := true })
  | .reset =>
    ({}, { seq := 1, direction := "RESET", summary := "Reset wallet to $100.00", frame := "CAPS/1" })

/-- Agent's naive retry draft: clears `delivery := .idle` on timeout, then subtracts $25.00 a second time. -/
def stepBuggyAgentRetry (l : Ledger) : Ledger :=
  let afterSend : Ledger :=
    { l with available := l.available - 2500, held := l.held + 2500, delivery := .inFlight "pay_1" 2500 }
  let afterTimeoutUnlocked : Ledger :=
    { afterSend with delivery := .idle }
  { afterTimeoutUnlocked with available := afterTimeoutUnlocked.available - 2500, delivery := .inFlight "pay_2" 2500 }

/-- Checked retry sequence (`reserve25 -> dropSocket -> reserve25`): locks `pay_1` and blocks duplicate charge. -/
def stepCheckedRetryComparison (srv : ServerMode) : Ledger :=
  let (l1, _) := stepVerifiedLedger srv {} .reserve25
  let (l2, _) := stepVerifiedLedger srv l1 .dropSocket
  let (l3, _) := stepVerifiedLedger srv l2 .reserve25
  l3

/-! ## 2. Homepage Flaky-Wi-Fi Checkout Simulator -/

inductive CheckoutMode where
  | agentDraft
  | lakeportFixed
  deriving DecidableEq, Repr, Inhabited

namespace CheckoutMode

def slug : CheckoutMode → String
  | .agentDraft => "draft"
  | .lakeportFixed => "checked"

def parse : String → CheckoutMode
  | "checked" => .lakeportFixed
  | _ => .agentDraft

end CheckoutMode

inductive NetworkRun where
  | idle
  | normalWifi
  | flakyWifi
  deriving DecidableEq, Repr, Inhabited

namespace NetworkRun

def slug : NetworkRun → String
  | .idle => "idle"
  | .normalWifi => "normal"
  | .flakyWifi => "flaky"

def parse : String → NetworkRun
  | "normal" => .normalWifi
  | "flaky" => .flakyWifi
  | _ => .idle

end NetworkRun

structure CheckoutOutcome where
  walletCents : Nat
  chargedCents : Nat
  overcharged : Bool
  headline : String
  step1 : String
  step2 : String
  step3 : String
  deriving DecidableEq, Repr

/-- Evaluates the $25.00 checkout in compiled Lean Wasm using `stepBuggyAgentRetry` vs `stepVerifiedLedger`. -/
def runCheckout (mode : CheckoutMode) (net : NetworkRun) : CheckoutOutcome :=
  let l0 : Ledger := {}
  match net with
  | .idle =>
    { walletCents := l0.totalCents
      chargedCents := 0
      overcharged := false
      headline := "Ready: customer has $100.00 to buy a $25.00 item"
      step1 := "Click \"Pay $25 on normal Wi-Fi\" to run what a unit test checks."
      step2 := "Click \"Pay $25 on flaky Wi-Fi\" to drop the connection mid-payment."
      step3 := "" }
  | .normalWifi =>
    let (l1, _) := stepVerifiedLedger .stagedDual l0 .reserve25
    let (l2, _) := stepVerifiedLedger .stagedDual l1 .settleMilestone
    { walletCents := l2.available
      chargedCents := l2.totalCents - l2.available
      overcharged := l2.totalCents != l0.totalCents
      headline :=
        match mode with
        | .agentDraft => "Unit test passed: charged $25.00 once ($75.00 left)"
        | .lakeportFixed => "Charged $25.00 once ($75.00 left in wallet)"
      step1 := "1. App sent $25.00 payment request to server."
      step2 := "2. Connection stayed up and server confirmed right away."
      step3 :=
        match mode with
        | .agentDraft => "3. Normal unit tests stop here, so the retry bug stays hidden."
        | .lakeportFixed => "3. Customer paid $25.00 once and received their receipt." }
  | .flakyWifi =>
    match mode with
    | .agentDraft =>
      let broken := stepBuggyAgentRetry l0
      { walletCents := broken.available
        chargedCents := l0.totalCents - broken.available
        overcharged := broken.totalCents != l0.totalCents
        headline := "Double-charged: $50.00 taken for a $25.00 order"
        step1 := "1. App sent $25.00 payment (pay_1), then Wi-Fi dropped before the reply."
        step2 := "2. Timeout handler cleared the \"sending\" flag to retry."
        step3 := "3. Retry sent a brand-new $25.00 payment (pay_2). Customer was billed twice." }
    | .lakeportFixed =>
      let checked := stepCheckedRetryComparison .stagedDual
      { walletCents := checked.available
        chargedCents := checked.totalCents - checked.available
        overcharged := checked.totalCents != l0.totalCents
        headline := "Charged $25.00 once even after Wi-Fi dropped"
        step1 := "1. App sent $25.00 payment (pay_1), then Wi-Fi dropped before the reply."
        step2 := "2. App kept pay_1 locked as awaiting confirmation instead of clearing it."
        step3 := "3. Reconnect checked pay_1 with the server instead of billing a second time." }

structure WorkbenchState where
  mode : CheckoutMode := .agentDraft
  netRun : NetworkRun := .idle
  ruleOpen : Bool := false
  deriving DecidableEq, Repr, Inhabited

def formatUsd (cents : Nat) : String :=
  let dollars := cents / 100
  let rem := cents % 100
  let pad := if rem < 10 then "0" ++ Nat.repr rem else Nat.repr rem
  "$" ++ Nat.repr dollars ++ "." ++ pad

/-! ## 3. Embedded `<ContractSimulator />` State (`04-versioned-contracts.mdx`) -/

inductive SimCommand where
  | reserve
  | milestone
  | instant
  deriving DecidableEq, Repr, Inhabited

namespace SimCommand

def slug : SimCommand → String
  | .reserve => "reserve"
  | .milestone => "milestone"
  | .instant => "instant"

def parse : String → SimCommand
  | "milestone" => .milestone
  | "instant" => .instant
  | _ => .reserve

def label : SimCommand → String
  | .reserve => "reserve ($25)"
  | .milestone => "releaseMilestone"
  | .instant => "instantRelease ($25)"

end SimCommand

structure ContractSimState where
  server : ServerMode := .stagedDual
  corruptAd : Bool := false
  cmd : SimCommand := .instant
  deriving DecidableEq, Repr, Inhabited

def simRawAdFields (s : ContractSimState) : List String :=
  if s.corruptAd then
    ["CAPS", "99", "lpw2", "unknown_cap"]
  else
    encodeAdvertisementFields s.server.advertisement

def simParsedAd (s : ContractSimState) : Option Advertisement :=
  parseAdvertisement (simRawAdFields s)

def simEncodedFrame (s : ContractSimState) : String :=
  match s.cmd with
  | .reserve =>
    match simParsedAd s >>= negotiateVersion with
    | some .v1 => V1.encodeReq (.reserve "cid-42" 2500)
    | _ => V2.encodeReq (.reserve "cid-42" 2500)
  | .milestone =>
    match simParsedAd s >>= negotiateVersion with
    | some .v1 => V1.encodeReq (.releaseMilestone "cid-42")
    | _ => V2.encodeReq (.releaseMilestone "cid-42")
  | .instant =>
    V2.encodeReq (.instantRelease "cid-42" 2500)

def simPermitted (s : ContractSimState) : Bool :=
  permitsEncodedFrame (simParsedAd s) (simEncodedFrame s)

/-! ## 4. `<RolloutTimeline />` (Backend-Agnostic Client Contract Pattern) -/

inductive RolloutStage where
  | stage1FrontendFirst
  | stage2DualServer
  | stage3EnableCap
  | stage4WithdrawRollback
  deriving DecidableEq, Repr, Inhabited

namespace RolloutStage

def all : List RolloutStage := [
  .stage1FrontendFirst, .stage2DualServer, .stage3EnableCap, .stage4WithdrawRollback
]

def index : RolloutStage → Nat
  | .stage1FrontendFirst => 1
  | .stage2DualServer => 2
  | .stage3EnableCap => 3
  | .stage4WithdrawRollback => 4

def ofIndex : Nat → RolloutStage
  | 1 => .stage1FrontendFirst
  | 2 => .stage2DualServer
  | 3 => .stage3EnableCap
  | _ => .stage4WithdrawRollback

def stageTag : RolloutStage → String
  | .stage1FrontendFirst => "Step 1"
  | .stage2DualServer => "Step 2"
  | .stage3EnableCap => "Step 3"
  | .stage4WithdrawRollback => "Step 4"

def shortTitle : RolloutStage → String
  | .stage1FrontendFirst => "Ship client"
  | .stage2DualServer => "Deploy backend"
  | .stage3EnableCap => "Enable feature"
  | .stage4WithdrawRollback => "Flip flag off"

def headline : RolloutStage → String
  | .stage1FrontendFirst => "Deploy the updated Lakeport app first while your backend still serves v1."
  | .stage2DualServer => "Roll out your Go, Node, Python, or Rust backend with v2 support while keeping the new flag off."
  | .stage3EnableCap => "Turn on the backend capability flag once the server deployment looks healthy."
  | .stage4WithdrawRollback => "Flip the backend flag off to hide the new feature without redeploying the app."

def serverAdSummary : RolloutStage → String
  | .stage1FrontendFirst => "Serving v1 responses only"
  | .stage2DualServer => "Serving v1 and v2 responses (instant payout flag off)"
  | .stage3EnableCap => "Serving v1 and v2 responses (instant payout flag on)"
  | .stage4WithdrawRollback => "Serving v1 and v2 responses (instant payout flag off)"

def cachedOldClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Continues using v1 as usual."
  | .stage2DualServer => "Continues using v1 without errors."
  | .stage3EnableCap => "Continues using v1 until the user refreshes."
  | .stage4WithdrawRollback => "Continues using v1 unaffected."

def newClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Understands both v1 and v2; keeps Instant Payout hidden."
  | .stage2DualServer => "Reads v2 responses; keeps Instant Payout hidden."
  | .stage3EnableCap => "Shows Instant Payout and sends v2 requests."
  | .stage4WithdrawRollback => "Hides Instant Payout as soon as capabilities refresh."

def admissionSummary : RolloutStage → String
  | .stage3EnableCap => "Allowed because your server advertises support"
  | _ => "Blocked in the client before any v2 request is sent"

def gateOpen : RolloutStage → Bool
  | .stage3EnableCap => true
  | _ => false

end RolloutStage

/-! ## 5. `<DeadCodeExplorer />` Reachability Model -/

inductive UsageProfile where
  | fullDocsSite
  | slugOnlyUtility
  | v1RetiredClean
  deriving DecidableEq, Repr, Inhabited

namespace UsageProfile

def slug : UsageProfile → String
  | .fullDocsSite => "full"
  | .slugOnlyUtility => "slug-only"
  | .v1RetiredClean => "v1-retired"

def parse : String → UsageProfile
  | "slug-only" => .slugOnlyUtility
  | "v1-retired" => .v1RetiredClean
  | _ => .fullDocsSite

def label : UsageProfile → String
  | .fullDocsSite => "Full Markdown + v1/v2 contract"
  | .slugOnlyUtility => "Heading slug helper only"
  | .v1RetiredClean => "After removing retired v1"

end UsageProfile

structure DceState where
  includeLedgerPkg : Bool := true
  includeChartsPkg : Bool := false
  profile : UsageProfile := .fullDocsSite
  deriving DecidableEq, Repr, Inhabited

structure DceMetrics where
  totalSourceLines : Nat
  theoremProofLines : Nat
  proofRuntimeBytes : Nat
  reachableDecls : Nat
  droppedDecls : Nat
  modeledSliceKb : Nat
  deriving DecidableEq, Repr

def computeDceMetrics (d : DceState) : DceMetrics :=
  let baseSource := 1840 + (if d.includeLedgerPkg then 920 else 0) + (if d.includeChartsPkg then 1150 else 0)
  let proofLines := 610 + (if d.includeLedgerPkg then 440 else 0) + (if d.includeChartsPkg then 290 else 0)
  let totalDecls := 148 + (if d.includeLedgerPkg then 64 else 0) + (if d.includeChartsPkg then 82 else 0)
  let reachable := match d.profile with
    | .fullDocsSite => 96 + (if d.includeLedgerPkg then 18 else 0) + (if d.includeChartsPkg then 0 else 0)
    | .slugOnlyUtility => 34 + (if d.includeLedgerPkg then 12 else 0)
    | .v1RetiredClean => 82 + (if d.includeLedgerPkg then 18 else 0)
  let sliceKb := match d.profile with
    | .fullDocsSite => 68 + (if d.includeLedgerPkg then 6 else 0)
    | .slugOnlyUtility => 41 + (if d.includeLedgerPkg then 4 else 0)
    | .v1RetiredClean => 62 + (if d.includeLedgerPkg then 6 else 0)
  { totalSourceLines := baseSource + proofLines
    theoremProofLines := proofLines
    proofRuntimeBytes := 0
    reachableDecls := reachable
    droppedDecls := totalDecls - reachable
    modeledSliceKb := sliceKb }

end Site.Demo
