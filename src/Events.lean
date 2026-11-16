import LakeportEffects
import State
/-!
# `Site.Events`: Typed UI Event Constructors & Reducer Dispatch

Centralizes `(Nat × String)` UI event tags and field edits so `Brand.lp`,
`Widgets.lp`, `Diagrams.lp`, `Marketing.lp`, `DocsView.lp`, and `App.lp` share one verified dispatch table.
-/
namespace Site
open LakeportEffects Site.Demo

abbrev UiEvent := Nat × String

namespace Ev

def nav (url : String) : UiEvent := (1, url)
def toggleTheme : UiEvent := (2, "")
def toggleMobileNav : UiEvent := (3, "")
def copy (key code : String) : UiEvent := (4, WirePack.packPair key code)

def wbMode (m : CheckoutMode) : UiEvent := (10, m.slug)
def wbRun (net : NetworkRun) : UiEvent := (11, net.slug)
def wbSeeCheckedFix : UiEvent := (12, "")
def wbToggleRule : UiEvent := (13, "")

def simScenario (sc : SimScenario) : UiEvent := (20, sc.slug)

def rollout (idx : Nat) : UiEvent := (30, Nat.repr idx)

def dceTogglePkg (pkg : String) : UiEvent := (40, pkg)
def dceProfile (p : UsageProfile) : UiEvent := (41, p.slug)

def sandboxPreset (name : String) : UiEvent := (50, name)
def clearDocsSearch : UiEvent := (51, "")

end Ev

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
  | (10, modeSlug) =>
    let m := CheckoutMode.parse modeSlug
    some (bump { s with workbench := { s.workbench with mode := m } }, [])
  | (11, netSlug) =>
    let net := NetworkRun.parse netSlug
    some (bump { s with workbench := { s.workbench with netRun := net } }, [])
  | (12, _) =>
    let wb' := { s.workbench with mode := .lakeportFixed, netRun := .flakyWifi }
    some (bump { s with workbench := wb' }, [])
  | (13, _) =>
    let wb' := { s.workbench with ruleOpen := !s.workbench.ruleOpen }
    some (bump { s with workbench := wb' }, [])
  | (20, scSlug) =>
    let sim' := { s.contractSim with scenario := SimScenario.parse scSlug }
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
