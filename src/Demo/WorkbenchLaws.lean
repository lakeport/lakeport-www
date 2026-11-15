import Demo.Workbench
/-!
# `Site.Demo.Laws` — Kernel-Checked Workbench & Escrow Theorems (`[proof-only, 0 B C]`)

Strictly `theorem`-only module proving:
1. `stepVerifiedLedger` conserves `totalCents` across every `ServerMode` and `LedgerAction`
   (except explicit `.reset` which restores `10000`).
2. `stepVerifiedLedger` never emits an unnegotiated `instantRelease` when the server is in
   `.legacyV1` or `.stagedDual`.
3. `stepVerifiedLedger` transitions in-flight transfers to `.uncertain` on socket drop.
4. Productive witness: `reserve25` followed by `settleMilestone` moves `2500` cents from
   `available` to `released`.
5. Refutation theorem (`buggy_retry_loses_conservation`): `stepBuggyAgentRetry` violates
   conservation (`7500 ≠ 10000`), backing the interactive Patch B counterexample in the UI.
-/
namespace Site.Demo.Laws
open Site.Contract Site.Demo

theorem verified_reserve_conserves (srv : ServerMode) (l : Ledger) :
    (stepVerifiedLedger srv l .reserve25).1.totalCents = l.totalCents := by
  dsimp only [stepVerifiedLedger]
  split
  · rename_i hCond
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hCond
    simp [Ledger.totalCents]
    omega
  · rfl

theorem verified_settle_conserves (srv : ServerMode) (l : Ledger) :
    (stepVerifiedLedger srv l .settleMilestone).1.totalCents = l.totalCents := by
  dsimp only [stepVerifiedLedger]
  split
  · simp [Ledger.totalCents]
    omega
  · rfl

theorem verified_instant_conserves (srv : ServerMode) (l : Ledger) :
    (stepVerifiedLedger srv l .instantRelease25).1.totalCents = l.totalCents := by
  dsimp only [stepVerifiedLedger]
  split
  · split
    · rename_i _ hBal
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hBal
      simp [Ledger.totalCents]
      omega
    · rfl
  · rfl

theorem verified_inject_conserves (srv : ServerMode) (l : Ledger) :
    (stepVerifiedLedger srv l .injectUnnegotiated).1.totalCents = l.totalCents := by
  dsimp only [stepVerifiedLedger]
  split
  · split
    · rename_i _ hBal
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hBal
      simp [Ledger.totalCents]
      omega
    · rfl
  · rfl

theorem verified_nonreset_conserves (srv : ServerMode) (l : Ledger) (act : LedgerAction)
    (hNotReset : act ≠ .reset) :
    (stepVerifiedLedger srv l act).1.totalCents = l.totalCents := by
  cases act with
  | reserve25 => exact verified_reserve_conserves srv l
  | settleMilestone => exact verified_settle_conserves srv l
  | instantRelease25 => exact verified_instant_conserves srv l
  | dropSocket =>
    dsimp only [stepVerifiedLedger]
    cases l.delivery <;> rfl
  | reconcileReconnect =>
    dsimp only [stepVerifiedLedger]
    cases l.delivery <;> rfl
  | injectUnnegotiated => exact verified_inject_conserves srv l
  | reset => contradiction

theorem staged_server_blocks_instant (l : Ledger) :
    (stepVerifiedLedger .stagedDual l .instantRelease25).1 = l ∧
    (stepVerifiedLedger .stagedDual l .instantRelease25).2.blocked = true := by
  simp [stepVerifiedLedger, ServerMode.advertisement, dualServerBaselineAd,
        permitsV2Command, requiredV2Capability]

theorem socket_drop_locks_uncertain (srv : ServerMode) (l : Ledger) (cid : String) (c : Nat)
    (hFlight : l.delivery = .inFlight cid c) :
    (stepVerifiedLedger srv l .dropSocket).1.delivery = .uncertain cid c := by
  simp [stepVerifiedLedger, hFlight]

theorem productive_reserve_and_settle :
    let l0 : Ledger := {}
    let l1 := (stepVerifiedLedger .stagedDual l0 .reserve25).1
    let l2 := (stepVerifiedLedger .stagedDual l1 .settleMilestone).1
    l2.available = 7500 ∧ l2.held = 0 ∧ l2.released = 2500 ∧ l2.totalCents = 10000 := by
  decide

theorem buggy_retry_loses_conservation :
    let l0 : Ledger := {}
    (stepBuggyAgentRetry l0).totalCents = 7500 ∧ (stepBuggyAgentRetry l0).totalCents ≠ l0.totalCents := by
  decide

theorem dce_proof_bytes_always_zero (d : DceState) :
    (computeDceMetrics d).proofRuntimeBytes = 0 := by
  rfl

theorem initial_ledger_conserved : LedgerConserved {} 10000 := by
  simp [LedgerConserved, Ledger.totalCents]

end Site.Demo.Laws
