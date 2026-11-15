import LakeportRouter
import LakeportEffects
import LakeportStyle.Memo
import LakeportMdx.Ast
import LakeportMdx.Parser
import Routes
import Docs.Registry
import Demo.Workbench
/-!
# `Site.State`: Pure Application State, Proved MDX MemoCell & Reducer

Single source of truth for navigation, theme preference, Homepage Checkout Simulator,
interactive docs widgets, live MDX Sandbox, and cached `MdxDoc` parsing (`MemoCell`).
-/
namespace Site
open LakeportRouter LakeportEffects LakeportStyle LakeportMdx Site.Docs Site.Demo

def defaultSandboxMdx : String :=
"---
title: \"Release notes\"
section: \"Sandbox\"
---

## Ship the client before your backend

Type in this box to watch **LakeportMdx** parse Markdown in compiled WebAssembly on every keystroke:

- Open browser tabs keep reading `v1` responses from your existing server.
- Updated `v2` buttons stay hidden until your backend turns on the feature flag.

<Callout kind=\"note\" title=\"No JavaScript markdown bundle\">
Headings, tables, code blocks, and callouts come directly from the compiled Lakeport app.
</Callout>"

def sandboxPresetContract : String :=
"---
title: \"Active API versions\"
section: \"Sandbox\"
---

## Client contract table

| Server version | Wire tag | Instant payout button |
| --- | --- | --- |
| `Version.v1` | `lpw1` | Hidden in client |
| `Version.v2` | `lpw2` | Shown when server advertises flag |

```lean title=\"shared/SiteContract/Api.lean\"
def clientHandler : (v : Version) -> Handler v
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
  docCache : MemoCell (Option DocSlug) MdxDoc (fun | some slug => parseDocSlug slug | none => {}) :=
    MemoCell.init (fun | some slug => parseDocSlug slug | none => {}) none
  sandboxCache : MemoCell (Option String) MdxDoc (fun | some raw => parseMdx raw | none => {}) :=
    MemoCell.init (fun | some raw => parseMdx raw | none => {}) none

instance : Inhabited AppState := ⟨{}⟩

/-- Synchronize `MemoCell` caches lazily when visiting `/docs/<slug>` or `/ecosystem`. -/
def syncCaches (s : AppState) : AppState :=
  let activeSlug := match s.router.activeRoute with
    | .docsPage slug => some slug
    | _ => s.docCache.input
  let activeSandbox := match s.router.activeRoute with
    | .ecosystem => some s.sandboxSource
    | _ => s.sandboxCache.input
  { s with
    docCache := s.docCache.refresh activeSlug
    sandboxCache := s.sandboxCache.refresh activeSandbox }

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
