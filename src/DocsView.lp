import LakeportMdx
import Docs.CatalogGen
import Docs.Registry
import State
import Events
import Widgets
set_option synthInstance.maxSize 4096
/-!
# `Site.DocsView` — 3-Column Technical Manual & Documentation Hub

Renders `/docs` (section overview) and `/docs/<slug>` (left search/section nav,
center MDX prose with embedded live Lakeport widgets, right sticky TOC, and prev/next pager).
-/
namespace Site.DocsView
open LakeportStyle LakeportMdx Site Site.Docs Site.Widgets

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

def docsIndexPage : V :=
  <div>
    <section class="hero-section">
      <div class="container">
        <div class="hero-grid">
          <div class="eyebrow"><span>Lakeport manual</span></div>
          <h1 class="hero-title">Documentation</h1>
          <p class="hero-lead">
            Practical guides written in plain English. Start by building a small app in ten minutes, then learn how we version edge contracts and roll out frontends without coordination headaches.
          </p>
          <div class="cta-row">
            {primaryBtn "Read Introduction" (Ev.nav "/docs/introduction")}
            {secondaryBtn "Jump to Your first app" (Ev.nav "/docs/getting-started")}
          </div>
        </div>
      </div>
    </section>

    <section class="section-block">
      <div class="container">
        {sectionsOrder.map fun sec =>
          <div class="section-head">
            <span class="section-kicker">{sec}</span>
            <div class="cards-3">
              {(docsInSection sec).map fun d =>
                <div class="feature-card" data-clickable={true}>
                  <button class="hit-overlay" onClick={Ev.nav ("/docs/" ++ d.slug)}>{d.title}</button>
                  <span class="docs-meta-row">{toString d.readingMinutes ++ " min read"}</span>
                  <h3 class="card-title">{d.title}</h3>
                  <p class="card-body">{d.summary}</p>
                  <span class="card-link-hint">{"Read chapter ->"}</span>
                </div>}
            </div>
          </div>}
      </div>
    </section>
  </div>

private def sidebarSection (active : DocSlug) (query : String) (sec : String) : V :=
  let items := (docsInSection sec).filter (matchesDocQuery query)
  if items.isEmpty then
    <span>{""}</span>
  else
    <div class="side-group">
      <span class="side-group-title">{sec}</span>
      {items.map fun d =>
        <div class="side-link" data-active={d == active}>
          <button class="hit-overlay" onClick={Ev.nav ("/docs/" ++ d.slug)}>{d.title}</button>
          <span class="side-link-text">{d.title}</span>
        </div>}
    </div>

def docsArticlePage (s : AppState) (slug : DocSlug) : V :=
  let doc := (s.docCache.refresh slug).get
  let (prevOpt, nextOpt) := neighbors slug
  <div class="docs-layout">
    <aside class="docs-sidebar">
      <div class="search-box">
        {svg "14" Icon.search}
        <input
          class="search-input"
          label="Filter chapters"
          placeholder="Filter chapters..."
          value={s.docsSearch}
          field={1}
        />
        {if s.docsSearch.isEmpty then <span>{""}</span>
         else <button class="search-clear" onClick={Ev.clearDocsSearch}>Clear</button>}
      </div>
      {sectionsOrder.map (sidebarSection slug s.docsSearch)}
    </aside>

    <main class="docs-main">
      <div class="docs-meta-row">
        <span>{slug.sectionName}</span>
        <span>{"/"}</span>
        <span>{toString slug.readingMinutes ++ " min read"}</span>
      </div>

      {renderBlocks (mdxHooks s) doc.blocks}

      <nav class="docs-pager">
        {(prevOpt.map fun prev =>
          (<div class="pager-card">
            <button class="hit-overlay" onClick={Ev.nav ("/docs/" ++ prev.slug)}>{"Previous: " ++ prev.title}</button>
            <span class="pager-dir">Previous chapter</span>
            <span class="pager-title">{prev.title}</span>
          </div> : V))}
        {(nextOpt.map fun nxt =>
          (<div class="pager-card">
            <button class="hit-overlay" onClick={Ev.nav ("/docs/" ++ nxt.slug)}>{"Next: " ++ nxt.title}</button>
            <span class="pager-dir">Next chapter</span>
            <span class="pager-title">{nxt.title}</span>
          </div> : V))}
      </nav>
    </main>

    <aside class="docs-toc">
      <span class="toc-heading">On this page</span>
      {doc.toc.map fun item =>
        <div class="toc-item" data-level={toString item.level}>
          <span>{item.title}</span>
        </div>}
    </aside>
  </div>

end Site.DocsView
