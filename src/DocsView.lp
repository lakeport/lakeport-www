import LakeportMdx
import Docs.CatalogGen
import Docs.Registry
import State
import Events
import Widgets
set_option synthInstance.maxSize 4096
/-!
# `Site.DocsView`: 3-Column Technical Manual & Documentation Hub

Renders `/docs` (ruled chapter index) and `/docs/<slug>` (left search/section nav,
center MDX prose with embedded live Lakeport widgets, right sticky TOC, and prev/next pager).
-/
namespace Site.DocsView
open LakeportStyle LakeportMdx Site Site.Docs Site.Widgets

abbrev V := StyledView UiEvent Nat

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

def docsIndexPage : V :=
  <main>
    <section class="hero-air">
      <div class="container">
        <div class="packages-intro">
          <h1 class="display-xl">Documentation</h1>
          <p class="lead-editorial">
            Twelve practical guides to building web and native apps with Lakeport, starting with a ten-minute starter project and growing into coding-agent workflows, client API contracts, and checked business rules. No prior Lean background required.
          </p>
          <div class="cta-row">
            {primaryBtn "Start with Introduction" (Ev.nav "/docs/introduction")}
            {inlineLinkBtn "Jump to Your first app →" (Ev.nav "/docs/getting-started")}
          </div>
        </div>
      </div>
    </section>

    <div class="waterline-rule" />

    <section class="editorial-section">
      <div class="container">
        {sectionsOrder.map fun sec =>
          <div class="docs-index-section">
            <h2 class="docs-index-heading">{sec}</h2>
            <div class="docs-index-list">
              {(docsInSection sec).map fun d =>
                <div class="docs-index-row">
                  <button class="hit-overlay" onClick={Ev.nav ("/docs/" ++ d.slug)}>{d.title}</button>
                  <div class="docs-index-title-col">
                    <span class="docs-index-title">{d.title}</span>
                    <span class="docs-index-read">{toString d.readingMinutes ++ " min read"}</span>
                  </div>
                  <p class="docs-index-summary">{d.summary}</p>
                  <span class="docs-index-arrow">{"→"}</span>
                </div>}
            </div>
          </div>}
      </div>
    </section>
  </main>

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
  let doc := (s.docCache.refresh (some slug)).get
  let (prevOpt, nextOpt) := neighbors slug
  <div class="docs-band">
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

      <div class="docs-pager">
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
      </div>
    </main>

    <aside class="docs-toc">
      <span class="toc-heading">On this page</span>
      {doc.toc.map fun item =>
        <div class="toc-item" data-level={toString item.level}>
          <span>{item.title}</span>
        </div>}
    </aside>
  </div>
  </div>

end Site.DocsView
