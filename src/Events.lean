import LakeportEffects
import State
/-!
# `Site.Events` — Typed UI Event Constructors & Reducer Dispatch

Centralizes `(Nat × String)` UI event tags and field edits so `Brand.lp`,
`Widgets.lp`, `Marketing.lp`, `DocsView.lp`, and `App.lp` share one verified dispatch table.
-/
namespace Site
open LakeportEffects Site.Demo

abbrev UiEvent := Nat × String

namespace Ev

def nav (url : String) : UiEvent := (1, url)
def toggleTheme : UiEvent := (2, "")
def toggleMobileNav : UiEvent := (3, "")
def copy (key code : String) : UiEvent := (4, WirePack.packPair key code)

def wbPatch (p : AgentPatch) : UiEvent := (10, p.slug)
def wbServer (m : ServerMode) : UiEvent := (11, m.slug)
def wbAction (act : String) : UiEvent := (12, act)
def wbCounterexample : UiEvent := (13, "")
def wbProofDrawer : UiEvent := (14, "")
def wbCompareChecked : UiEvent := (15, "")
def wbContractExplorer : UiEvent := (16, "")

def simServer (m : ServerMode) : UiEvent := (20, m.slug)
def simCorrupt : UiEvent := (21, "")
def simCommand (c : SimCommand) : UiEvent := (22, c.slug)

def rollout (idx : Nat) : UiEvent := (30, Nat.repr idx)

def dceTogglePkg (pkg : String) : UiEvent := (40, pkg)
def dceProfile (p : UsageProfile) : UiEvent := (41, p.slug)

def sandboxPreset (name : String) : UiEvent := (50, name)
def clearDocsSearch : UiEvent := (51, "")

end Ev

private def decodeLedgerAction (raw : String) : LedgerAction :=
  if raw == "reserve" then .reserve25
  else if raw == "settle" then .settleMilestone
  else if raw == "instant" then .instantRelease25
  else if raw == "drop" then .dropSocket
  else if raw == "reconcile" then .reconcileReconnect
  else if raw == "inject" then .injectUnnegotiated
  else .reset

def handlePress (s : AppState) (ev : UiEvent) : Option (AppState × List Lakeport.Signals.Term) :=
  match ev with
  | (1, url) =>
    some (navigateToUrl s url, [])
  | (2, _) =>
    some (bump { s with theme := s.theme.next }, [])
  | (3, _) =>
    some (bump { s with mobileNavOpen := !s.mobileNavOpen }, [])
  | (4, packed) =>
    match WirePack.unpackPair packed with
    | some (k, code) =>
      let (s', reqs) := copySnippet s k code
      some (s', reqs.map EffectReq.toTerm)
    | none => some (s, [])
  | (10, pSlug) =>
    let p := AgentPatch.parse pSlug
    let preview := if p == .buggyRetry then s.workbench.buggyPreview else none
    some (bump { s with workbench := { s.workbench with patch := p, buggyPreview := preview } }, [])
  | (11, srvSlug) =>
    let srv := ServerMode.parse srvSlug
    let adEntry : WireLogEntry := {
      seq := s.workbench.ledger.nextCid
      direction := "CAPS"
      summary := "Switched backend advertisement → " ++ srv.label
      frame := "\t".intercalate (Site.Contract.encodeAdvertisementFields srv.advertisement)
    }
    let wb' := { s.workbench with server := srv, logs := pushLog s.workbench adEntry }
    some (bump { s with workbench := wb' }, [])
  | (12, actSlug) =>
    let wb' := applyWorkbenchAction s.workbench (decodeLedgerAction actSlug)
    some (bump { s with workbench := wb' }, [])
  | (13, _) =>
    some (bump { s with workbench := triggerCounterexample s.workbench }, [])
  | (14, _) =>
    let wb' := { s.workbench with proofDrawerOpen := !s.workbench.proofDrawerOpen }
    some (bump { s with workbench := wb' }, [])
  | (15, _) =>
    some (bump { s with workbench := triggerCheckedComparison s.workbench }, [])
  | (16, _) =>
    let wb' := { s.workbench with contractExplorerOpen := !s.workbench.contractExplorerOpen }
    some (bump { s with workbench := wb' }, [])
  | (20, srvSlug) =>
    let sim' := { s.contractSim with server := ServerMode.parse srvSlug, corruptAd := false }
    some (bump { s with contractSim := sim' }, [])
  | (21, _) =>
    let sim' := { s.contractSim with corruptAd := !s.contractSim.corruptAd }
    some (bump { s with contractSim := sim' }, [])
  | (22, cmdSlug) =>
    let sim' := { s.contractSim with cmd := SimCommand.parse cmdSlug }
    some (bump { s with contractSim := sim' }, [])
  | (30, idxStr) =>
    let idx := (parseDecimalNat? idxStr).getD 1
    some (bump { s with rolloutStage := RolloutStage.ofIndex idx }, [])
  | (40, pkg) =>
    let dce' :=
      if pkg == "ledger" then { s.dce with includeLedgerPkg := !s.dce.includeLedgerPkg }
      else { s.dce with includeChartsPkg := !s.dce.includeChartsPkg }
    some (bump { s with dce := dce' }, [])
  | (41, profSlug) =>
    let dce' := { s.dce with profile := UsageProfile.parse profSlug }
    some (bump { s with dce := dce' }, [])
  | (50, preset) =>
    let src := if preset == "contract" then sandboxPresetContract else defaultSandboxMdx
    some (bump { s with sandboxPreset := preset, sandboxSource := src }, [])
  | (51, _) =>
    some (bump { s with docsSearch := "" }, [])
  | _ => none

def handleEdit (s : AppState) (field : Nat) (val : String) : AppState × List Lakeport.Signals.Term :=
  if field == 1 then
    (bump { s with docsSearch := val }, [])
  else if field == 2 then
    (bump { s with sandboxPreset := "custom", sandboxSource := val }, [])
  else
    (s, [])

end Site
