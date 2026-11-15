import LakeportRouter
import LakeportEffects
import Routes
import State
import Events
import Brand
import Widgets
import Marketing
import DocsView
set_option synthInstance.maxSize 4096
/-!
# `App` — Lakeport Website & Technical Manual Root (`App.app`)

Mounts `RouterShell`, solid editorial navigation chrome, brand theme tokens,
and all 17 pre-rendered SSG routes (`0 sorryAx`).
-/
namespace App
open Lakeport.Signals LakeportStyle LakeportRouter LakeportEffects
open Site Site.Brand Site.Widgets Site.Marketing Site.DocsView

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

private def themeIcon (t : ThemePref) : List V :=
  match t with
  | .auto => Icon.autoHalf
  | .light => Icon.sun
  | .dark => Icon.moon

private def themeShort (t : ThemePref) : String :=
  match t with
  | .auto => "Auto"
  | .light => "Light"
  | .dark => "Dark"

def headerView (s : AppState) : V :=
  let r := s.router.activeRoute
  <header class="topbar">
    <div class="topbar-inner">
      <div class="brand-wrap">
        <button class="hit-overlay" onClick={Ev.nav "/"}>Lakeport home</button>
        {logoLockup "header"}
      </div>

      <div class="topbar-right">
        <nav class="nav-links">
          {navLink (isDocsActive r) "Docs" "/docs/introduction"}
          {navLink (r == .whyLean) "Why Lean" "/why-lean"}
          {navLink (r == .ecosystem) "Packages" "/ecosystem"}
          {navLink (r == .showcase) "Examples" "/showcase"}
        </nav>

        <div class="theme-btn">
          <button class="hit-overlay" onClick={Ev.toggleTheme}>{s.theme.buttonLabel}</button>
          {svg "14" (themeIcon s.theme)}
          <span class="theme-btn-text">{themeShort s.theme}</span>
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
        {navLink (isDocsActive r) "Docs" "/docs/introduction"}
        {navLink (r == .whyLean) "Why Lean" "/why-lean"}
        {navLink (r == .ecosystem) "Packages" "/ecosystem"}
        {navLink (r == .showcase) "Examples" "/showcase"}
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
      <div class="footer-top">
        <div class="footer-brand-col">
          <div class="footer-logo-wrap">
            <button class="hit-overlay" onClick={Ev.nav "/"}>Lakeport home</button>
            {logoLockup "footer"}
          </div>
          <span class="footer-tagline">Apps your agents can prove.</span>
        </div>

        <nav class="footer-nav">
          {footerLink "Docs" "/docs/introduction"}
          {footerLink "First app" "/docs/getting-started"}
          {footerLink "All chapters" "/docs"}
          {footerLink "Why Lean" "/why-lean"}
          {footerLink "Packages" "/ecosystem"}
          {footerLink "Examples" "/showcase"}
          {footerLink "CLI & MCP" "/docs/cli-and-mcp"}
        </nav>
      </div>

      <div class="footer-colophon">
        <span>Built in Lean 4 with Lakeport · 17 static HTML routes · 0 sorryAx</span>
        <span class="footer-qed">∎</span>
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
    <div class="site-shell" data-theme={s.theme.attr}>
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
