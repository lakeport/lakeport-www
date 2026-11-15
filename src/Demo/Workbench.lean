import SiteContract.Versions
import SiteContract.Wire
import SiteContract.Api
/-!
# `Site.Demo` — Verified Escrow Workbench, Rollout Track & Reachability Model

Pure Lean domain state machines backing:
1. Homepage **"One retry. $25 missing." Live WebAssembly Demonstration** (`WorkbenchState`)
2. Docs **`<ContractSimulator />`** (`ContractSimState`)
3. Homepage & Docs **`<RolloutTimeline />`** (`RolloutStage`)
4. Packages & Docs **`<DeadCodeExplorer />`** (`DceState`)
-/
namespace Site.Demo
open Site.Contract Site.Contract.Wire

/-! ## 1. Agent Patch Modes & Server Profiles -/

inductive AgentPatch where
  | verified      -- Checked reducer: exhaustive union + Gate.permits + uncertain delivery lock
  | buggyRetry    -- Agent's patch: clears inFlight & double-debits on socket retry (refuted by Lean)
  | unhandledV3   -- Recorded compile fixture: adds Version.v3 without updating clientHandler
  deriving DecidableEq, Repr, Inhabited

namespace AgentPatch

def slug : AgentPatch → String
  | .verified => "verified"
  | .buggyRetry => "buggy-retry"
  | .unhandledV3 => "unhandled-v3"

def parse : String → AgentPatch
  | "buggy-retry" => .buggyRetry
  | "unhandled-v3" => .unhandledV3
  | _ => .verified

end AgentPatch

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
  | .legacyV1 => "v1 legacy"
  | .stagedDual => "v1 + v2 (gate off)"
  | .fullV2 => "v2 + instant_release"

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

/-- Total funds across all three escrow buckets (in cents). -/
def Ledger.totalCents (l : Ledger) : Nat :=
  l.available + l.held + l.released

/-- Quarter units (`0..4`) of `$100.00` for visual bar proportioning. -/
def centsQuarterTag (cents : Nat) : String :=
  if cents == 0 then "0"
  else if cents <= 2500 then "1"
  else if cents <= 5000 then "2"
  else if cents <= 7500 then "3"
  else "4"

/-- Erased `Prop` invariant proved in `WorkbenchLaws.lean`. -/
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

/-- Checked transition function (`stepVerifiedLedger`).
    Every non-reset branch conserves `totalCents` and enforces `permitsV2Command` / `permitsEncodedFrame`. -/
def stepVerifiedLedger (srv : ServerMode) (l : Ledger) : LedgerAction → Ledger × WireLogEntry
  | .reserve25 =>
    let cid := "cid-" ++ Nat.repr l.nextCid
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
       { seq := l.nextCid, direction := "OUT", summary := "Reserved $25.00 into escrow", frame })
    else
      (l, { seq := l.nextCid, direction := "HOLD",
            summary := "Second reserve blocked while uncertain transfer awaits sync",
            frame := "noop", blocked := true })
  | .settleMilestone =>
    let cid := "cid-" ++ Nat.repr l.nextCid
    if l.held > 0 then
      let frame := V2.encodeResp (.ack cid l.available 0 (l.released + l.held) "rcpt-verified")
      ({ l with
          held := 0
          released := l.released + l.held
          delivery := .idle
          nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "ACK", summary := "Settled held escrow to recipient", frame })
    else
      (l, { seq := l.nextCid, direction := "HOLD", summary := "No held escrow to settle", frame := "noop", blocked := true })
  | .instantRelease25 =>
    let cid := "cid-" ++ Nat.repr l.nextCid
    let cmd := V2.ClientFrame.instantRelease cid 2500
    if permitsV2Command (some srv.advertisement) cmd then
      if l.delivery == .idle && 2500 <= l.available then
        let frame := V2.encodeReq cmd
        ({ l with
            available := l.available - 2500
            released := l.released + 2500
            nextCid := l.nextCid + 1 },
         { seq := l.nextCid, direction := "OUT+ACK", summary := "Negotiated v2 instant release ($25.00)", frame })
      else
        (l, { seq := l.nextCid, direction := "HOLD", summary := "Await uncertain transfer or top up balance", frame := "noop", blocked := true })
    else
      let raw := V2.encodeReq cmd
      (l, { seq := l.nextCid, direction := "GATE",
            summary := "Command blocked: server has not advertised instant_release",
            frame := raw, blocked := true })
  | .dropSocket =>
    match l.delivery with
    | .inFlight cid cents =>
      ({ l with delivery := .uncertain cid cents },
       { seq := l.nextCid, direction := "NET",
         summary := "Socket closed before ack -> marked .uncertain (" ++ cid ++ " locked)",
         frame := "wsClose(1006, abnormal)" })
    | .uncertain cid _ =>
      (l, { seq := l.nextCid, direction := "NET",
            summary := "Already awaiting idempotent reconciliation for " ++ cid,
            frame := "wsClose(1006)" })
    | .idle =>
      (l, { seq := l.nextCid, direction := "NET",
            summary := "Socket dropped while idle (no in-flight escrow at risk)",
            frame := "wsClose(1006)" })
  | .reconcileReconnect =>
    match l.delivery with
    | .uncertain cid _ =>
      let frame := V2.encodeResp (.ack cid l.available l.held l.released ("reconciled-" ++ cid))
      ({ l with delivery := .idle, nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "SYNC",
         summary := "Reconciled " ++ cid ++ " idempotently (0 duplicate debits)",
         frame })
    | .inFlight cid _ =>
      ({ l with delivery := .idle, nextCid := l.nextCid + 1 },
       { seq := l.nextCid, direction := "ACK", summary := "Confirmed in-flight " ++ cid, frame := "ack(" ++ cid ++ ")" })
    | .idle =>
      (l, { seq := l.nextCid, direction := "SYNC", summary := "Outbox clean; capabilities refreshed", frame := "CAPS/1" })
  | .injectUnnegotiated =>
    let cid := "adv-" ++ Nat.repr l.nextCid
    let forged := V2.encodeReq (.instantRelease cid 2500)
    if permitsEncodedFrame (some srv.advertisement) forged then
      if l.delivery == .idle && 2500 <= l.available then
        ({ l with available := l.available - 2500, released := l.released + 2500, nextCid := l.nextCid + 1 },
         { seq := l.nextCid, direction := "OUT", summary := "Server advertises instant_release; frame admitted", frame := forged })
      else
        (l, { seq := l.nextCid, direction := "HOLD", summary := "Admitted by gate, skipped by balance/flight lock", frame := forged, blocked := true })
    else
      (l, { seq := l.nextCid, direction := "BLOCKED",
            summary := "permitsEncodedFrame rejected unnegotiated v2 frame before socket write",
            frame := forged, blocked := true })
  | .reset =>
    ({}, { seq := 1, direction := "INIT", summary := "Reset ledger to $100.00 available", frame := "CAPS/1" })

/-- Faulty agent retry logic: clears `delivery := .idle` on socket drop and
    re-debits `available` without crediting `held` when retrying, losing $25.00 of conservation. -/
def stepBuggyAgentRetry (l : Ledger) : Ledger :=
  let afterReserve : Ledger :=
    { l with available := l.available - 2500, held := l.held + 2500, delivery := .inFlight "cid-1" 2500 }
  let afterDropUnlocked : Ledger :=
    { afterReserve with delivery := .idle }
  { afterDropUnlocked with available := afterDropUnlocked.available - 2500, delivery := .inFlight "cid-2" 2500 }

/-- Deterministic 3-step checked comparison (`reserve25 -> dropSocket -> reserve25`).
    Demonstrates that the checked reducer locks `cid-1` as `.uncertain` and blocks the duplicate retry. -/
def stepCheckedRetryComparison (srv : ServerMode) : Ledger × List WireLogEntry :=
  let (l1, e1) := stepVerifiedLedger srv {} .reserve25
  let (l2, e2) := stepVerifiedLedger srv l1 .dropSocket
  let (l3, e3) := stepVerifiedLedger srv l2 .reserve25
  (l3, [e3, e2, e1])

structure WorkbenchState where
  patch : AgentPatch := .buggyRetry
  server : ServerMode := .stagedDual
  ledger : Ledger := {}
  buggyPreview : Option Ledger := none
  checkedCompared : Bool := false
  proofDrawerOpen : Bool := false
  contractExplorerOpen : Bool := false
  logs : List WireLogEntry := [
    { seq := 0, direction := "BOOT",
      summary := "Negotiated lpw2 baseline; instant_release capability currently OFF",
      frame := "CAPS\t1\tlpw1,lpw2\taudit_receipt" }
  ]
  deriving DecidableEq, Repr, Inhabited

def formatUsd (cents : Nat) : String :=
  let dollars := cents / 100
  let rem := cents % 100
  let pad := if rem < 10 then "0" ++ Nat.repr rem else Nat.repr rem
  "$" ++ Nat.repr dollars ++ "." ++ pad

def pushLog (w : WorkbenchState) (entry : WireLogEntry) : List WireLogEntry :=
  (entry :: w.logs).take 5

def applyWorkbenchAction (w : WorkbenchState) (act : LedgerAction) : WorkbenchState :=
  let (l', logEntry) := stepVerifiedLedger w.server w.ledger act
  { w with
    patch := .verified
    ledger := l'
    buggyPreview := none
    checkedCompared := if act == .reset then false else w.checkedCompared
    logs := if act == .reset then [logEntry] else pushLog w logEntry }

def triggerCounterexample (w : WorkbenchState) : WorkbenchState :=
  let broken := stepBuggyAgentRetry {}
  let entry : WireLogEntry := {
    seq := w.ledger.nextCid + 1
    direction := "COUNTEREX"
    summary := "Counterexample executed: $50.00 available + $25.00 held + $0.00 released = $75.00"
    frame := "totalCents = 7500 != 10000"
    blocked := true
  }
  { w with
    patch := .buggyRetry
    buggyPreview := some broken
    checkedCompared := false
    logs := pushLog w entry }

def triggerCheckedComparison (w : WorkbenchState) : WorkbenchState :=
  let (l3, entries) := stepCheckedRetryComparison w.server
  { w with
    patch := .verified
    ledger := l3
    buggyPreview := none
    checkedCompared := true
    logs := (entries ++ w.logs).take 5 }

/-! ## 2. Embedded `<ContractSimulator />` State -/

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

/-! ## 3. Embedded `<RolloutTimeline />` 4-Stage Track -/

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

def stepNumber : RolloutStage → String
  | .stage1FrontendFirst => "01"
  | .stage2DualServer => "02"
  | .stage3EnableCap => "03"
  | .stage4WithdrawRollback => "04"

def shortTitle : RolloutStage → String
  | .stage1FrontendFirst => "Ship frontend"
  | .stage2DualServer => "Dual server"
  | .stage3EnableCap => "Enable capability"
  | .stage4WithdrawRollback => "Withdraw flag"

def headline : RolloutStage → String
  | .stage1FrontendFirst => "Ship the new client first while the capability gate stays closed."
  | .stage2DualServer => "Update backend pods to serve both v1 and v2 while the capability stays off."
  | .stage3EnableCap => "Advertise instant_release in GET /api/capabilities to open the gate."
  | .stage4WithdrawRollback => "Withdraw the capability flag to hide the control without redeploying binaries."

def serverAdSummary : RolloutStage → String
  | .stage1FrontendFirst => "versions: [lpw1] · capabilities: []"
  | .stage2DualServer => "versions: [lpw1, lpw2] · capabilities: [audit_receipt]"
  | .stage3EnableCap => "versions: [lpw1, lpw2] · capabilities: [instant_release, audit_receipt]"
  | .stage4WithdrawRollback => "versions: [lpw1, lpw2] · capabilities: [audit_receipt]"

def cachedOldClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Speaks lpw1 normally; never sees v2 messages."
  | .stage2DualServer => "Continues speaking lpw1 against dual-version pods."
  | .stage3EnableCap => "Continues speaking lpw1 until the tab refreshes."
  | .stage4WithdrawRollback => "Unaffected; lpw1 baseline stays online."

def newClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Understands v2; keeps Instant Release hidden."
  | .stage2DualServer => "Frames baseline traffic in lpw2; Instant Release stays hidden."
  | .stage3EnableCap => "Reveals Instant Release control; Gate.permits admits commands."
  | .stage4WithdrawRollback => "Hides control on capability refresh; rejects unnegotiated v2 writes."

def admissionSummary : RolloutStage → String
  | .stage3EnableCap => "instantRelease admitted (Gate.permits = true)"
  | _ => "instantRelease blocked before socket write (Gate.permits = false)"

def gateOpen : RolloutStage → Bool
  | .stage3EnableCap => true
  | _ => false

end RolloutStage

/-! ## 4. Embedded `<DeadCodeExplorer />` Illustrative Reachability Model -/

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
  | .fullDocsSite => "Full MDX + v1/v2 contract"
  | .slugOnlyUtility => "LakeportMdx.slugify only"
  | .v1RetiredClean => "After retiring Version.v1"

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
