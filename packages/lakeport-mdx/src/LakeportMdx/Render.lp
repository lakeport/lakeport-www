import LakeportMdx.Ast
import LakeportMdx.Highlight
import_css MdxCss from "./Mdx.css"
set_option synthInstance.maxSize 4096
/-!
# `LakeportMdx.Render` — StyledView Renderer for Parsed MDX Documents

Renders `MdxDoc` into `LakeportStyle.StyledView E F` using the scoped `MdxCss` module,
connecting copy-code buttons, internal route links, and embedded Lakeport JSX widgets.
-/
namespace LakeportMdx
open LakeportStyle

@[default_instance] instance {E F : Type} : ToChildren (List (StyledView E F)) E F :=
  ⟨fun xs => xs.zipIdx.map fun (v, i) => (some i, v)⟩

/-- Host hooks supplied by the consuming Lakeport application. -/
structure RenderHooks (E F : Type) where
  onNavigate : String → E
  onCopy : String → String → E
  copiedKey : String := ""
  renderWidget : String → List (String × String) → StyledView E F

private def tokClass : TokKind → ClassName
  | .plain => MdxCss.tokPlain
  | .keyword => MdxCss.tokKeyword
  | .tactic => MdxCss.tokTactic
  | .typeName => MdxCss.tokType
  | .decl => MdxCss.tokDecl
  | .stringLit => MdxCss.tokString
  | .comment => MdxCss.tokComment
  | .tag => MdxCss.tokTag
  | .attr => MdxCss.tokAttr
  | .number => MdxCss.tokNumber

def renderInline {E F : Type} (hooks : RenderHooks E F) : Inline → StyledView E F
  | .text s => <span>{s}</span>
  | .code s => <span class={MdxCss.inlineCode}>{s}</span>
  | .strong s => <span class={MdxCss.strongSpan}>{s}</span>
  | .em s => <span class={MdxCss.emSpan}>{s}</span>
  | .link label href =>
    if href.startsWith "/" then
      <span class={MdxCss.linkWrap}>
        <button class={MdxCss.linkHit} onClick={hooks.onNavigate href}>{label}</button>
        <span class={MdxCss.linkText}>{label}</span>
      </span>
    else
      <span class={MdxCss.linkText}>{label}</span>

def renderInlines {E F : Type} (hooks : RenderHooks E F) (xs : List Inline) : List (StyledView E F) :=
  xs.map (renderInline hooks)

def renderCodeBlock {E F : Type} (hooks : RenderHooks E F) (idx : Nat) (lang title code : String) : StyledView E F :=
  let copyId := "mdx-code-" ++ toString idx
  let isCopied := hooks.copiedKey == copyId
  let lines := highlightCode lang code
  <div class={MdxCss.codeCard}>
    <div class={MdxCss.codeHead}>
      <div class={MdxCss.codeMeta}>
        <span class={MdxCss.langBadge}>{lang}</span>
        {if title.isEmpty then <span>{""}</span> else <span class={MdxCss.codeTitle}>{title}</span>}
      </div>
      <button class={MdxCss.copyBtn} data-copied={isCopied} onClick={hooks.onCopy copyId code}>
        {if isCopied then "Copied" else "Copy"}
      </button>
    </div>
    <div class={MdxCss.codePre}>
      {lines.map fun toks =>
        <div class={MdxCss.codeLine}>
          {toks.map fun (kind, txt) => <span class={tokClass kind}>{txt}</span>}
        </div>}
    </div>
  </div>

def renderBlock {E F : Type} (hooks : RenderHooks E F) (idx : Nat) : Block → StyledView E F
  | .heading lvl slug inls _ =>
    if lvl == 1 then
      <h1 class={MdxCss.h1} data-anchor={slug}>{renderInlines hooks inls}</h1>
    else if lvl == 2 then
      <div class={MdxCss.h2Row} data-anchor={slug}>
        <h2 class={MdxCss.h2}>{renderInlines hooks inls}</h2>
        <span class={MdxCss.anchorHash}>{"#" ++ slug}</span>
      </div>
    else
      <div class={MdxCss.h3Row} data-anchor={slug}>
        <h3 class={MdxCss.h3}>{renderInlines hooks inls}</h3>
      </div>
  | .paragraph inls =>
    <p class={MdxCss.para}>{renderInlines hooks inls}</p>
  | .codeBlock lang title code =>
    renderCodeBlock hooks idx lang title code
  | .bulletList items =>
    <div class={MdxCss.listBlock}>
      {items.map fun item =>
        <div class={MdxCss.listRow}>
          <span class={MdxCss.bulletGlyph}>{"•"}</span>
          <div class={MdxCss.listBody}>{renderInlines hooks item}</div>
        </div>}
    </div>
  | .orderedList items =>
    <div class={MdxCss.listBlock}>
      {items.zipIdx.map fun (item, n) =>
        <div class={MdxCss.listRow}>
          <span class={MdxCss.bulletGlyph}>{toString (n + 1) ++ "."}</span>
          <div class={MdxCss.listBody}>{renderInlines hooks item}</div>
        </div>}
    </div>
  | .table headers rows =>
    <div class={MdxCss.tableWrap}>
      <div class={MdxCss.tableGrid}>
        <div class={MdxCss.tableHeaderRow}>
          {headers.map fun h => <div class={MdxCss.tableHeaderCell}>{h}</div>}
        </div>
        {rows.map fun r =>
          <div class={MdxCss.tableRow}>
            {r.map fun cell => <div class={MdxCss.tableCell}>{renderInlines hooks cell}</div>}
          </div>}
      </div>
    </div>
  | .blockquote inls =>
    <div class={MdxCss.quote}>{renderInlines hooks inls}</div>
  | .callout kind title paras =>
    <div class={MdxCss.callout} data-kind={kind.slug}>
      <div class={MdxCss.calloutHead}><span>{title}</span></div>
      <div class={MdxCss.calloutBody}>
        {paras.map fun p => <p>{renderInlines hooks p}</p>}
      </div>
    </div>
  | .component name props =>
    <div class={MdxCss.widgetSlot}>{hooks.renderWidget name props}</div>
  | .thematicBreak =>
    <div class={MdxCss.divider} />

/-- Render all blocks of a parsed `MdxDoc` inside a semantic article container. -/
def renderBlocks {E F : Type} (hooks : RenderHooks E F) (blocks : List Block) : StyledView E F :=
  <div class={MdxCss.article}>
    {blocks.zipIdx.map fun (b, i) => renderBlock hooks i b}
  </div>

end LakeportMdx
