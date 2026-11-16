import LakeportJson.Codec
import SiteContract.Versions
import SiteContract.Wire
import SiteContract.Api
/-!
# `Site.Demo` : Checkout Retry Demo, JSON Schema Union Simulator & Rollout Model

Pure Lean domain logic compiled to WebAssembly for:
1. Homepage flaky-Wi-Fi checkout simulator (`CheckoutMode`, `NetworkRun`, `runCheckout`)
2. Underlying escrow & capability state machine (`Ledger`, `stepVerifiedLedger`)
3. Docs `<ContractSimulator />` (real `LakeportJson` frontend schema union + optional HTTP headers),
   `<RolloutTimeline />`, and `<DeadCodeExplorer />`
-/
namespace Site.Demo
open LakeportJson Site.Contract Site.Contract.Wire

/-! ## 1. Server Capability Profiles & Verified Ledger Core -/

inductive ServerMode where
  | legacyV1
  | stagedDual
  | fullV2
  deriving DecidableEq, Repr, Inhabited

namespace ServerMode

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
        | some .v2 => (clientHandler .v2).encode (.reserve cid 2500)
        | _ => (clientHandler .v1).encode (.reserve cid 2500)
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
        let frame := (clientHandler .v2).encode cmd
        ({ l with
            available := l.available - 2500
            released := l.released + 2500
            nextCid := l.nextCid + 1 },
         { seq := l.nextCid, direction := "ACK", summary := "Processed instant v2 payment ($25.00)", frame })
      else
        (l, { seq := l.nextCid, direction := "LOCK", summary := "Payment already in progress", frame := "noop", blocked := true })
    else
      let raw := (clientHandler .v2).encode cmd
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
    let forged := (clientHandler .v2).encode (.instantRelease cid 2500)
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

/-- Checked retry sequence: send `pay_1`, drop socket into `.uncertain`, then attempt duplicate `.reserve25`. -/
def stepCheckedRetryComparison (srv : ServerMode) : Ledger :=
  let l0 : Ledger := {}
  let l1 := (stepVerifiedLedger srv l0 .reserve25).1
  let l2 := (stepVerifiedLedger srv l1 .dropSocket).1
  (stepVerifiedLedger srv l2 .reserve25).1

/-! ## 2. Homepage Flaky-Wi-Fi Checkout Simulator -/

inductive CheckoutMode where
  | agentDraft
  | lakeportFixed
  deriving DecidableEq, Repr, Inhabited

namespace CheckoutMode

def slug : CheckoutMode → String
  | .agentDraft => "draft"
  | .lakeportFixed => "fixed"

def parse : String → CheckoutMode
  | "fixed" => .lakeportFixed
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

def runCheckout (mode : CheckoutMode) (net : NetworkRun) : CheckoutOutcome :=
  let l0 : Ledger := {}
  match net with
  | .idle =>
    { walletCents := l0.available
      chargedCents := 0
      overcharged := false
      headline := "Ready: customer wallet has $100.00"
      step1 := "1. Pick normal Wi-Fi to run the standard unit-test path."
      step2 := "2. Pick flaky Wi-Fi to drop the connection right after the first $25.00 request leaves."
      step3 := "3. Compare what the agent's first draft does against Lakeport's checked fix." }
  | .normalWifi =>
    let settled := (stepVerifiedLedger .stagedDual (stepVerifiedLedger .stagedDual l0 .reserve25).1 .settleMilestone).1
    { walletCents := settled.available
      chargedCents := settled.released
      overcharged := false
      headline := "Unit test passed: charged $25.00 once"
      step1 := "1. App sent $25.00 payment (pay_1)."
      step2 := "2. Server replied 200 OK right away."
      step3 := "3. Both implementations pass this happy-path unit test." }
  | .flakyWifi =>
    match mode with
    | .agentDraft =>
      let broken := stepBuggyAgentRetry l0
      let billed := l0.available - broken.available
      { walletCents := broken.available
        chargedCents := billed
        overcharged := billed > 2500
        headline := "Customer billed $50.00 for a single $25.00 item"
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

/-! ## 3. Frontend JSON Schema Union & Header Simulator (`05-versioned-contracts.mdx`) -/

structure OrderV1 where
  id : String
  totalCents : Nat
  status : String
  deriving DecidableEq, Repr

structure OrderV2 where
  id : String
  cents : Nat
  currency : String
  refundable : Bool
  deriving DecidableEq, Repr

/-- Frontend union of active backend JSON schemas (`src/Api/Orders.lean`). -/
inductive OrderSchema where
  | v1 (order : OrderV1)
  | v2 (order : OrderV2)
  deriving DecidableEq, Repr

/-- Parse raw JSON from any Go, Node, Python, or Rust server into `OrderSchema` using `LakeportJson`. -/
def decodeOrderSchema (rawJson : String) : Option OrderSchema :=
  match Json.parse rawJson with
  | .error _ => none
  | .ok j =>
    match (do
      let id ← j.fieldAs String "id"
      let amt ← j.field "amount"
      let cents ← amt.fieldAs Nat "cents"
      let currency ← amt.fieldAs String "currency"
      let refundable ← j.fieldAs Bool "refundable"
      pure (OrderSchema.v2 { id, cents, currency, refundable })) with
    | .ok v2Order => some v2Order
    | .error _ =>
      match (do
        let id ← j.fieldAs String "id"
        let totalCents ← j.fieldAs Nat "total_cents"
        let status ← j.fieldAs String "status"
        pure (OrderSchema.v1 { id, totalCents, status })) with
      | .ok v1Order => some v1Order
      | .error _ => none

inductive SimScenario where
  | v1Server
  | v2NoHeader
  | v2WithHeader
  | badGateway
  deriving DecidableEq, Repr, Inhabited

namespace SimScenario

def all : List SimScenario := [
  .v1Server, .v2NoHeader, .v2WithHeader, .badGateway
]

def slug : SimScenario → String
  | .v1Server => "v1-json"
  | .v2NoHeader => "v2-json"
  | .v2WithHeader => "v2-header"
  | .badGateway => "bad-json"

def parse : String → SimScenario
  | "v2-json" => .v2NoHeader
  | "v2-header" => .v2WithHeader
  | "bad-json" => .badGateway
  | _ => .v1Server

def label : SimScenario → String
  | .v1Server => "1. Backend v1 JSON"
  | .v2NoHeader => "2. Backend v2 JSON (no header)"
  | .v2WithHeader => "3. Backend v2 + capability header"
  | .badGateway => "4. Unexpected v99 JSON"

def httpHeaders : SimScenario → String
  | .v1Server => "HTTP/1.1 200 OK  |  Content-Type: application/json"
  | .v2NoHeader => "HTTP/1.1 200 OK  |  Content-Type: application/json"
  | .v2WithHeader => "HTTP/1.1 200 OK  |  X-API-Version: 2  |  X-Capabilities: instant-refund"
  | .badGateway => "HTTP/1.1 200 OK  |  Content-Type: application/json"

def rawJson : SimScenario → String
  | .v1Server => "{\"id\":\"ord-42\",\"total_cents\":2500,\"status\":\"paid\"}"
  | .v2NoHeader => "{\"id\":\"ord-42\",\"amount\":{\"cents\":2500,\"currency\":\"USD\"},\"refundable\":false}"
  | .v2WithHeader => "{\"id\":\"ord-42\",\"amount\":{\"cents\":2500,\"currency\":\"USD\"},\"refundable\":true}"
  | .badGateway => "{\"schema\":99,\"unexpected\":true}"

def hasRefundHeader : SimScenario → Bool
  | .v2WithHeader => true
  | _ => false

end SimScenario

structure ContractSimState where
  scenario : SimScenario := .v1Server
  deriving DecidableEq, Repr, Inhabited

structure SimOutcome where
  matchedBranch : String
  schemaValid : Bool
  receiptText : String
  refundButtonAllowed : Bool
  refundStatus : String
  deriving DecidableEq, Repr

/-- Exhaustive frontend handler over `OrderSchema` (`0` wildcard arms on active schemas). -/
def evaluateContractSim (s : ContractSimState) : SimOutcome :=
  let sc := s.scenario
  match decodeOrderSchema sc.rawJson with
  | some (.v1 o) =>
    { matchedBranch := "OrderSchema.v1 (matched from JSON shape alone, no version header needed)"
      schemaValid := true
      receiptText := "Order " ++ o.id ++ ": " ++ formatUsd o.totalCents ++ " (" ++ o.status ++ ")"
      refundButtonAllowed := false
      refundStatus := "Hidden: server returned v1 JSON and did not advertise instant-refund" }
  | some (.v2 o) =>
    let canRefund := o.refundable && sc.hasRefundHeader
    { matchedBranch :=
        if sc.hasRefundHeader then
          "OrderSchema.v2 (nested amount JSON + X-Capabilities: instant-refund header)"
        else
          "OrderSchema.v2 (matched from nested amount JSON without a capability endpoint)"
      schemaValid := true
      receiptText := "Order " ++ o.id ++ ": " ++ formatUsd o.cents ++ " " ++ o.currency
      refundButtonAllowed := canRefund
      refundStatus :=
        if canRefund then
          "Shown: POST /api/orders/ord-42/refund enabled by v2 schema + header"
        else
          "Hidden: v2 receipt renders fine, while instant-refund write stays gated off" }
  | none =>
    { matchedBranch := "none (fail-closed: unknown schema rejected cleanly)"
      schemaValid := false
      receiptText := "Fallback banner shown; previous client state kept intact"
      refundButtonAllowed := false
      refundStatus := "Blocked: response did not match OrderSchema.v1 or OrderSchema.v2" }

/-! ## 4. `<RolloutTimeline />` (Frontend-First Release & Service Worker Overlap) -/

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
  | .stage1FrontendFirst => "Ship frontend"
  | .stage2DualServer => "Deploy backend"
  | .stage3EnableCap => "Advertise header"
  | .stage4WithdrawRollback => "Retire v1 branch"

def headline : RolloutStage → String
  | .stage1FrontendFirst => "Add OrderSchema.v2 to src/Api/ and ship the Lakeport frontend while your server still returns v1 JSON."
  | .stage2DualServer => "Roll out your Go, Node, Python, or Rust backend returning v2 JSON while keeping new write capabilities off."
  | .stage3EnableCap => "Expose X-Capabilities (or a feature flag field) once the backend rollout is healthy so updated clients show v2 actions."
  | .stage4WithdrawRollback => "Once server logs show zero v1 responses and Service Worker caches have rotated, delete OrderSchema.v1 and let lakeport check verify cleanup."

def serverAdSummary : RolloutStage → String
  | .stage1FrontendFirst => "Returning v1 JSON"
  | .stage2DualServer => "Returning v2 JSON (no instant-refund header)"
  | .stage3EnableCap => "Returning v2 JSON + X-Capabilities: instant-refund"
  | .stage4WithdrawRollback => "Returning v2 JSON only (v1 retired on server)"

def cachedOldClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Service Worker cached bundle decodes v1 JSON as usual."
  | .stage2DualServer => "Dual-schema bundle in cache decodes both v1 and v2 JSON."
  | .stage3EnableCap => "Older cached tab keeps reading responses until next reload."
  | .stage4WithdrawRollback => "Active clients are on v2; v1 decoder branch deleted cleanly."

def newClientBehavior : RolloutStage → String
  | .stage1FrontendFirst => "Accepts v1 or v2 JSON; keeps v2 write button hidden."
  | .stage2DualServer => "Renders v2 JSON immediately; keeps v2 write button hidden."
  | .stage3EnableCap => "Renders v2 JSON and enables the v2 write button."
  | .stage4WithdrawRollback => "Compiles with OrderSchema.v2 only after v1 retirement."

def admissionSummary : RolloutStage → String
  | .stage3EnableCap => "Enabled when backend advertises capability header or flag"
  | .stage4WithdrawRollback => "v2 write active; dead v1 code removed from bundle"
  | _ => "Gated off in client reducer before any v2 write is sent"

def gateOpen : RolloutStage → Bool
  | .stage3EnableCap => true
  | .stage4WithdrawRollback => true
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
  | .fullDocsSite => "Full Markdown + v1/v2 schemas"
  | .slugOnlyUtility => "Heading slug helper only"
  | .v1RetiredClean => "After deleting retired v1"

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
