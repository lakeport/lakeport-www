import LakeportRouter
import LakeportEffects
import Routes
import State
import Events
import Widgets
import Marketing
import DocsView
set_option synthInstance.maxSize 4096
/-!
# `App` — Lakeport Marketing & Documentation Site Root (`App.app`)

Mounts `RouterShell`, global chrome, theme tokens, and routes across all 17
pre-rendered SSG routes, compiling to WebAssembly with `0 sorryAx`.
-/
namespace App
open Lakeport.Signals LakeportStyle LakeportRouter LakeportEffects Site Site.Widgets Site.Marketing Site.DocsView

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

private def isDocsActive (r : SiteRoute) : Bool :=
  match r with
  | .docsIndex | .docsPage _ => true
  | _ => false

private def navLink (active : Bool) (label href : String) : V :=
  <div class="nav-item" data-active={active}>
    <button class="hit-overlay" onClick={Ev.nav href}>{label}</button>
    <span class="nav-item-label">{label}</span>
  </div>

def headerView (s : AppState) : V :=
  let r := s.router.activeRoute
  <header class="topbar">
    <div class="topbar-inner">
      <div class="brand-wrap">
        <button class="hit-overlay" onClick={Ev.nav "/"}>Lakeport home</button>
        <div class="brand-mark">{svg "16" Icon.shield}</div>
        <span class="brand-name">Lakeport</span>
        <span class="brand-tag">Lean 4</span>
      </div>

      <nav class="nav-links">
        {navLink (r == .home) "Overview" "/"}
        {navLink (isDocsActive r) "Docs" "/docs/introduction"}
        {navLink (r == .whyLean) "Why Lean" "/why-lean"}
        {navLink (r == .ecosystem) "Reservoir & MDX" "/ecosystem"}
        {navLink (r == .showcase) "Showcase" "/showcase"}
      </nav>

      <div class="topbar-right">
        <div class="wasm-badge">
          <span class="wasm-dot" />
          <span>wasm32 • 0 sorryAx</span>
        </div>
        <div class="icon-btn">
          <button class="hit-overlay" onClick={Ev.toggleTheme}>
            {if s.darkTheme then "Switch to light theme" else "Switch to dark theme"}
          </button>
          {svg "16" (if s.darkTheme then Icon.sun else Icon.moon)}
        </div>
        <div class="icon-btn mobile-menu-btn">
          <button class="hit-overlay" onClick={Ev.toggleMobileNav}>Toggle navigation menu</button>
          {svg "18" (if s.mobileNavOpen then Icon.close else Icon.menu)}
        </div>
      </div>
    </div>

    {if s.mobileNavOpen then
      <div class="mobile-drawer">
        {navLink (r == .home) "Overview" "/"}
        {navLink (isDocsActive r) "Documentation" "/docs/introduction"}
        {navLink (r == .whyLean) "Why Lean" "/why-lean"}
        {navLink (r == .ecosystem) "Reservoir & Live MDX" "/ecosystem"}
        {navLink (r == .showcase) "Showcase" "/showcase"}
      </div>
     else <span>{""}</span>}
  </header>

private def footerLink (label href : String) : V :=
  <div class="footer-link">
    <button class="hit-overlay" onClick={Ev.nav href}>{label}</button>
    <span class="footer-link-text">{label}</span>
  </div>

def footerView : V :=
  <footer class="site-footer">
    <div class="container">
      <div class="footer-inner">
        <div class="footer-col">
          <span class="footer-title">Lakeport</span>
          <p class="footer-note">
            Built entirely in Lakeport (Lean 4, .lp TSX, scoped .css, and lakeport-mdx). Pre-rendered across 17 static HTML routes from compiled WebAssembly.
          </p>
        </div>
        <div class="footer-col">
          <span class="footer-title">Getting started</span>
          {footerLink "Introduction" "/docs/introduction"}
          {footerLink "Installation" "/docs/installation"}
          {footerLink "Your first app" "/docs/getting-started"}
          {footerLink "Browse all chapters" "/docs"}
        </div>
        <div class="footer-col">
          <span class="footer-title">Recommended patterns</span>
          {footerLink "Versioned union contracts" "/docs/versioned-contracts"}
          {footerLink "Frontend-first releases" "/docs/frontend-first-releases"}
          {footerLink "Pure core & Lean proofs" "/docs/pure-core-and-proofs"}
          {footerLink "Reservoir & bundle size" "/docs/reservoir-and-bundle-size"}
        </div>
        <div class="footer-col">
          <span class="footer-title">Architecture</span>
          {footerLink "Why Lean 4" "/why-lean"}
          {footerLink "Live MDX sandbox" "/ecosystem"}
          {footerLink "Reference apps" "/showcase"}
          {footerLink "CLI & MCP reference" "/docs/cli-and-mcp"}
        </div>
      </div>
    </div>
  </footer>

def routeBody (s : AppState) : V :=
  match s.router.activeRoute with
  | .home => homePage s
  | .whyLean => whyLeanPage
  | .ecosystem => ecosystemPage s
  | .showcase => showcasePage
  | .docsIndex => docsIndexPage
  | .docsPage slug => docsArticlePage s slug

def view (s : AppState) : V :=
  let url := routePath s.router.activeRoute
  <RouterShell url={url} canBack={s.router.canGoBack}>
    <div class="site-shell" data-theme={if s.darkTheme then "dark" else "light"}>
      {headerView s}
      {routeBody s}
      {footerView}
    </div>
  </RouterShell>

inductive Msg where
  | effect (r : EffectResp)
  | router (r : RouterMsg)

def decodeNamed (id : Nat) (bytes : Lakeport.DataCodec.Bytes) : Except InboundError Msg :=
  match decodeEffectNamed? id bytes with
  | some r => r.map Msg.effect
  | none =>
    match decodeRouterNamed? id bytes with
    | some r => r.map Msg.router
    | none => .error (.codec .badTag)

def message (s : AppState) : Msg → AppState × List Lakeport.Signals.Term
  | .router (.navigate url) => (navigateToUrl s url, [])
  | .router .back => (bump { s with router := s.router.applyBack }, [])
  | .effect _ => (s, [])

def app : StyledApp AppState Msg UiEvent Nat where
  initial := fun _ => {}
  view := view
  encodeEvent := fun (tag, payload) => .pair (.nat tag) (.string payload)
  decodeEvent := fun | .pair (.nat tag) (.string payload) => some (tag, payload) | _ => none
  encodeField := .nat
  decodeField := fun | .nat n => some n | _ => none
  press := fun s ev => (handlePress s ev).getD (s, [])
  edit := fun s f v => some (handleEdit s f v)
  message := message
  decodeNamed := decodeNamed
  commandImage := effectCommandImage
  appCommit := fun s => s.commit
  descriptor := "lakeport-www/1"
  profile := ⟨⟨32, 65536⟩, ⟨32, 65536⟩⟩

end App
