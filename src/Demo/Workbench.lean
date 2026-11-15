import SiteContract.Versions
import SiteContract.Wire
import SiteContract.Api
/-!
# `Site.Demo` — Verified Escrow Workbench, Rollout Scrubber & Dead-Code Explorer

Pure Lean domain state machines backing:
1. Homepage **"Agent Patch vs. Lean Kernel" Live Workbench** (`WorkbenchState`)
2. Docs **`<ContractSimulator />`** (`ContractSimState`)
3. Homepage & Docs **`<RolloutTimeline />`** (`RolloutStage`)
4. Ecosystem & Docs **`<DeadCodeExplorer />`** (`DceState`)
-/
namespace Site.Demo
open Site.Contract Site.Contract.Wire

/-! ## 1. Agent Patch Modes & Server Profiles -/

inductive AgentPatch where
  | verified      -- Patch A: exhaustive union + Gate.permits + uncertain delivery lock
  | buggyRetry    -- Patch B: clears inFlight & double-debits on socket retry (refuted by Lean)
  | unhandledV3   -- Patch C: adds Version.v3 without updating clientHandler (compile error)
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

def badge : AgentPatch → String
  | .verified => "KERNEL ACCEPTED"
  | .buggyRetry => "PROOF REFUTED"
  | .unhandledV3 => "TYPE ERROR"

def title : AgentPatch → String
  | .verified => "Patch A: Verified escrow + gate"
  | .buggyRetry => "Patch B: Agent naive retry fix"
  | .unhandledV3 => "Patch C: Unhandled Version.v3"

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
  | .legacyV1 => "Server: v1 legacy"
  | .stagedDual => "Server: v1+v2 (gate closed)"
  | .fullV2 => "Server: v2 + instant_release"

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

/-- Verified production transition function (`Patch A`).
    Every branch conserves `totalCents` and enforces `permitsV2Command` / `permitsEncodedFrame`. -/
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
            summary := "Reserve skipped (reconcile in-flight transfer or check balance)",
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
       { seq := l.nextCid, direction := "ACK", summary := "Server settled held escrow to recipient", frame })
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
            summary := "Gate.permits = false (server has not advertised instant_release)",
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

/-- Buggy AI agent retry logic (`Patch B`): clears `delivery := .idle` on socket drop and
    re-debits `available` without crediting `held` when retrying, losing $25.00 of conservation! -/
def stepBuggyAgentRetry (l : Ledger) : Ledger :=
  let afterReserve : Ledger :=
    { l with available := l.available - 2500, held := l.held + 2500, delivery := .inFlight "cid-1" 2500 }
  let afterDropUnlocked : Ledger :=
    { afterReserve with delivery := .idle }
  -- Bug: agent retries debiting `available` while server already committed the first debit separately
  { afterDropUnlocked with available := afterDropUnlocked.available - 2500, delivery := .inFlight "cid-2" 2500 }

structure WorkbenchState where
  patch : AgentPatch := .verified
  server : ServerMode := .stagedDual
  ledger : Ledger := {}
  buggyPreview : Option Ledger := none
  proofDrawerOpen : Bool := false
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
    ledger := l'
    buggyPreview := none
    logs := if act == .reset then [logEntry] else pushLog w logEntry }

def triggerCounterexample (w : WorkbenchState) : WorkbenchState :=
  let broken := stepBuggyAgentRetry {}
  let entry : WireLogEntry := {
    seq := w.ledger.nextCid + 1
    direction := "COUNTEREX"
    summary := "Lean refuted Patch B: available=$50 + held=$25 + released=$0 = $75.00 (!= $100.00)"
    frame := "totalCents = 7500 != 10000"
    blocked := true
  }
  { w with patch := .buggyRetry, buggyPreview := some broken, logs := pushLog w entry }

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

/-! ## 3. Embedded `<RolloutTimeline />` 4-Stage Scrubber -/

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

def shortTitle : RolloutStage → String
  | .stage1FrontendFirst => "1. Ship frontend"
  | .stage2DualServer => "2. Dual server"
  | .stage3EnableCap => "3. Enable flag"
  | .stage4WithdrawRollback => "4. Safe rollback"

def headline : RolloutStage → String
  | .stage1FrontendFirst => "Release the new Lakeport client first (capability gate closed)"
  | .stage2DualServer => "Roll out backend pods serving both v1 and v2 (flag still off)"
  | .stage3EnableCap => "Advertise instant_release in GET /api/capabilities"
  | .stage4WithdrawRollback => "Withdraw capability flag to roll back in seconds without redeploying"

def serverAdSummary : RolloutStage → String
  | .stage1FrontendFirst => "versions: [lpw1]  |  capabilities: []"
  | .stage2DualServer => "versions: [lpw1, lpw2]  |  capabilities: [audit_receipt]"
  | .stage3EnableCap => "versions: [lpw1, lpw2]  |  capabilities: [instant_release, audit_receipt]"
  | .stage4WithdrawRollback => "versions: [lpw1, lpw2]  |  capabilities: [audit_receipt]"

def cachedOldClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Speaks lpw1 normally; zero awareness of v2."
  | .stage2DualServer => "Continues speaking lpw1 against dual-version pods without errors."
  | .stage3EnableCap => "Continues speaking lpw1 until tab refreshes."
  | .stage4WithdrawRollback => "Unaffected; lpw1 baseline stays online."

def newClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Negotiates lpw1; hides Instant Release button; Gate blocks v2 frames."
  | .stage2DualServer => "Upgrades baseline framing to lpw2; Instant Release stays hidden & gated."
  | .stage3EnableCap => "Reveals Instant Release control; Gate.permits opens for instantRelease."
  | .stage4WithdrawRollback => "Hides control on capability refresh; outbox holds unnegotiated v2 retries."

def gateOpen : RolloutStage → Bool
  | .stage3EnableCap => true
  | _ => false

end RolloutStage

/-! ## 4. Embedded `<DeadCodeExplorer />` Reservoir Bundle Calculator -/

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
  | .fullDocsSite => "App uses full MDX + v1/v2 contract"
  | .slugOnlyUtility => "App calls LakeportMdx.slugify only"
  | .v1RetiredClean => "After retiring Version.v1 via .ilean"

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
  gzipWasmKb : Nat
  deriving DecidableEq, Repr

def computeDceMetrics (d : DceState) : DceMetrics :=
  let baseSource := 1840 + (if d.includeLedgerPkg then 920 else 0) + (if d.includeChartsPkg then 1150 else 0)
  let proofLines := 610 + (if d.includeLedgerPkg then 440 else 0) + (if d.includeChartsPkg then 290 else 0)
  let totalDecls := 148 + (if d.includeLedgerPkg then 64 else 0) + (if d.includeChartsPkg then 82 else 0)
  let reachable := match d.profile with
    | .fullDocsSite => 96 + (if d.includeLedgerPkg then 18 else 0) + (if d.includeChartsPkg then 0 else 0)
    | .slugOnlyUtility => 34 + (if d.includeLedgerPkg then 12 else 0)
    | .v1RetiredClean => 82 + (if d.includeLedgerPkg then 18 else 0)
  let wasmKb := match d.profile with
    | .fullDocsSite => 68 + (if d.includeLedgerPkg then 6 else 0)
    | .slugOnlyUtility => 41 + (if d.includeLedgerPkg then 4 else 0)
    | .v1RetiredClean => 62 + (if d.includeLedgerPkg then 6 else 0)
  { totalSourceLines := baseSource + proofLines
    theoremProofLines := proofLines
    proofRuntimeBytes := 0
    reachableDecls := reachable
    droppedDecls := totalDecls - reachable
    gzipWasmKb := wasmKb }

end Site.Demo
