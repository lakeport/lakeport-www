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

Single source of truth for navigation, theme preference, Homepage Workbench,
interactive docs widgets, live MDX Sandbox, and cached `MdxDoc` parsing (`MemoCell`).
-/
namespace Site
open LakeportRouter LakeportEffects LakeportStyle LakeportMdx Site.Docs Site.Demo

def defaultSandboxMdx : String :=
"---
title: \"Release notes\"
section: \"Sandbox\"
---

## Ship the frontend first

Edit this source to watch **LakeportMdx** parse and render on keystroke in `wasm32`:

- Older clients continue speaking `lpw1`.
- Enable `instant_release` once dual-version pods are healthy.

```lean title=\"CapabilityCheck.lean\"
theorem gate_closed_by_default (cmd : V2.ClientFrame) :
    permitsV2Command none cmd = false := by
  rfl
```

<Callout kind=\"note\" title=\"Zero JS parser\">
The AST, heading slugs, and syntax tokens come from compiled Lean WebAssembly.
</Callout>"

def sandboxPresetContract : String :=
"---
title: \"Contract union snippet\"
section: \"Sandbox\"
---

## Versioned wire table

| Version | Wire tag | Instant release |
| --- | --- | --- |
| `Version.v1` | `lpw1` | Blocked at Gate |
| `Version.v2` | `lpw2` | Permitted when advertised |

```lean title=\"shared/SiteContract/Api.lean\"
def clientHandler : (v : Version) → Handler v
  | .v1 => { encode := Wire.V1.encodeReq, decode := Wire.V1.decodeResp }
  | .v2 => { encode := Wire.V2.encodeReq, decode := Wire.V2.decodeResp }
```"

inductive ThemePref where
  | auto
  | light
  | dark
  deriving DecidableEq, Repr, Inhabited

namespace ThemePref

def attr : ThemePref → String
  | .auto => "auto"
  | .light => "light"
  | .dark => "dark"

def next : ThemePref → ThemePref
  | .auto => .light
  | .light => .dark
  | .dark => .auto

def buttonLabel : ThemePref → String
  | .auto => "Theme: Auto"
  | .light => "Theme: Light"
  | .dark => "Theme: Dark"

end ThemePref

structure AppState where
  router : RouterState SiteRoute := RouterState.ofRoot .home
  theme : ThemePref := .auto
  mobileNavOpen : Bool := false
  docsSearch : String := ""
  copiedKey : String := ""
  sandboxPreset : String := "notes"
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
