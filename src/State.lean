import LakeportRouter
import LakeportEffects
import LakeportStyle.Memo
import LakeportMdx.Ast
import LakeportMdx.Parser
import Routes
import Docs.Registry
import Demo.Workbench
/-!
# `Site.State` — Pure Application State, Proved MDX MemoCell & Reducer

Single source of truth for navigation, theme, Homepage Workbench, interactive docs
widgets, live MDX Sandbox, and cached `MdxDoc` parsing (`MemoCell`).
-/
namespace Site
open LakeportRouter LakeportEffects LakeportStyle LakeportMdx Site.Docs Site.Demo

def defaultSandboxMdx : String :=
"---
title: \"Edge capability note\"
section: \"Sandbox\"
---

## Live pure-Lean MDX

Edit this source to watch **LakeportMdx** re-parse and highlight in `wasm32`:

- Zero JavaScript markdown libraries (`0 B` runtime JS parser)
- Scoped `import_css` stylesheet with typed `ClassName` exports

```lean title=\"CapabilityCheck.lean\"
theorem gate_closed_by_default (cmd : V2.ClientFrame) :
    permitsV2Command none cmd = false := by
  rfl
```

<Callout kind=\"tip\" title=\"Try editing me\">
Add a bullet, table, or heading above and watch the AST and right-rail TOC update immediately.
</Callout>"

def sandboxPresetContract : String :=
"---
title: \"Contract union snippet\"
section: \"Sandbox\"
---

## Exhaustive version table

| Version | Wire tag | Instant release |
| --- | --- | --- |
| `Version.v1` | `lpw1` | Blocked at Gate |
| `Version.v2` | `lpw2` | Permitted when advertised |

```lean title=\"shared/SiteContract/Api.lean\"
def clientHandler : (v : Version) -> Handler v
  | .v1 => { encode := Wire.V1.encodeReq, decode := Wire.V1.decodeResp }
  | .v2 => { encode := Wire.V2.encodeReq, decode := Wire.V2.decodeResp }
```"

structure AppState where
  router : RouterState SiteRoute := RouterState.ofRoot .home
  darkTheme : Bool := true
  mobileNavOpen : Bool := false
  docsSearch : String := ""
  copiedKey : String := ""
  nextReqId : Nat := 1
  commit : Nat := 0
  workbench : WorkbenchState := {}
  contractSim : ContractSimState := {}
  rolloutStage : RolloutStage := .stage1FrontendFirst
  dce : DceState := {}
  sandboxSource : String := defaultSandboxMdx
  docCache : MemoCell DocSlug MdxDoc parseDocSlug := MemoCell.init parseDocSlug .introduction
  sandboxCache : MemoCell String MdxDoc parseMdx := MemoCell.init parseMdx defaultSandboxMdx

instance : Inhabited AppState := ⟨{}⟩

/-- Synchronize `MemoCell` caches whenever active doc slug or sandbox text changes. -/
def syncCaches (s : AppState) : AppState :=
  let activeSlug := match s.router.activeRoute with
    | .docsPage slug => slug
    | _ => s.docCache.input
  { s with
    docCache := s.docCache.refresh activeSlug
    sandboxCache := s.sandboxCache.refresh s.sandboxSource }

/-- Bump monotonic app commit counter and refresh proved caches. -/
def bump (s : AppState) : AppState :=
  syncCaches { s with commit := s.commit + 1 }

/-- Navigate to `rawUrl` via `routeCodec`, closing transient mobile nav. -/
def navigateToUrl (s : AppState) (rawUrl : String) : AppState :=
  let target := parseSiteUrl rawUrl
  bump { s with
    router := s.router.navigateRoute classifyRoute target
    mobileNavOpen := false }

/-- Copy `code` to the host clipboard and highlight `key` button state. -/
def copySnippet (s : AppState) (key code : String) : AppState × List EffectReq :=
  let reqId := s.nextReqId
  let next := bump { s with copiedKey := key, nextReqId := reqId + 1 }
  (next, [.clipboardWrite reqId code])

end Site
