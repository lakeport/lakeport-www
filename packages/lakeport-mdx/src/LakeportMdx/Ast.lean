/-!
# `LakeportMdx.Ast` — Pure MDX Document AST & Slug Invariants

Pure `Init`-only data definitions for MDX documents, frontmatter metadata,
table-of-contents items, inline spans, block nodes, and URL-safe heading slugs.
-/
namespace LakeportMdx

/-- Metadata header parsed from `--- ... ---` at the top of an `.mdx` document. -/
structure Frontmatter where
  title : String := ""
  summary : String := ""
  sectionName : String := "Guide"
  order : Nat := 0
  readingMinutes : Nat := 5
  updated : String := ""
  deriving DecidableEq, Repr, Inhabited

/-- Admonition callout severity rendered by `<Callout kind="...">`. -/
inductive CalloutKind where
  | note
  | tip
  | important
  | warning
  deriving DecidableEq, Repr, Inhabited

namespace CalloutKind

def slug : CalloutKind → String
  | .note => "note"
  | .tip => "tip"
  | .important => "important"
  | .warning => "warning"

def defaultTitle : CalloutKind → String
  | .note => "Note"
  | .tip => "Tip"
  | .important => "Important"
  | .warning => "Watch out"

def ofString : String → CalloutKind
  | "tip" => .tip
  | "important" => .important
  | "warning" => .warning
  | "caution" => .warning
  | _ => .note

end CalloutKind

/-- Inline rich-text spans inside headings, paragraphs, list items, and table cells. -/
inductive Inline where
  | text (s : String)
  | code (s : String)
  | strong (s : String)
  | em (s : String)
  | link (label : String) (href : String)
  deriving DecidableEq, Repr, Inhabited

/-- Extract plain readable text from an `Inline` span. -/
def Inline.plain : Inline → String
  | .text s => s
  | .code s => s
  | .strong s => s
  | .em s => s
  | .link label _ => label

def inlinesPlain (xs : List Inline) : String :=
  String.join (xs.map Inline.plain)

/-- Right-rail table-of-contents anchor extracted from `##` and `###` headings. -/
structure TocItem where
  level : Nat
  slug : String
  title : String
  deriving DecidableEq, Repr, Inhabited

/-- Block-level MDX AST node, including embedded Lakeport interactive components. -/
inductive Block where
  | heading (level : Nat) (slug : String) (inlines : List Inline) (plain : String)
  | paragraph (inlines : List Inline)
  | codeBlock (lang : String) (title : String) (code : String)
  | bulletList (items : List (List Inline))
  | orderedList (items : List (List Inline))
  | table (headers : List String) (rows : List (List (List Inline)))
  | blockquote (inlines : List Inline)
  | callout (kind : CalloutKind) (title : String) (paragraphs : List (List Inline))
  | component (name : String) (props : List (String × String))
  | thematicBreak
  deriving DecidableEq, Repr, Inhabited

/-- Complete parsed `.mdx` document with frontmatter, blocks, and derived TOC. -/
structure MdxDoc where
  frontmatter : Frontmatter := {}
  blocks : List Block := []
  toc : List TocItem := []
  deriving DecidableEq, Repr, Inhabited

/-- Allowed characters in a generated heading anchor slug. -/
def isSlugChar (c : Char) : Bool :=
  (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-'

/-- Erased `Prop` specification for safe anchor slugs (`0` runtime bytes). -/
def SafeSlug (s : String) : Prop :=
  s.toList ≠ [] ∧ ∀ c ∈ s.toList, isSlugChar c = true

/-- Map one character to a lowercase slug char (`none` for punctuation/whitespace). -/
def asciiUpperToLower? : Char → Option Char
  | 'A' => some 'a' | 'B' => some 'b' | 'C' => some 'c' | 'D' => some 'd'
  | 'E' => some 'e' | 'F' => some 'f' | 'G' => some 'g' | 'H' => some 'h'
  | 'I' => some 'i' | 'J' => some 'j' | 'K' => some 'k' | 'L' => some 'l'
  | 'M' => some 'm' | 'N' => some 'n' | 'O' => some 'o' | 'P' => some 'p'
  | 'Q' => some 'q' | 'R' => some 'r' | 'S' => some 's' | 'T' => some 't'
  | 'U' => some 'u' | 'V' => some 'v' | 'W' => some 'w' | 'X' => some 'x'
  | 'Y' => some 'y' | 'Z' => some 'z'
  | _ => none

def toSlugAlphaNum? (c : Char) : Option Char :=
  if c >= 'a' && c <= 'z' then some c
  else if c >= '0' && c <= '9' then some c
  else asciiUpperToLower? c

/-- Collapse raw characters into hyphen-separated lowercase alphanumeric runs. -/
def slugCharsAux : List Char → Bool → List Char
  | [], _ => []
  | c :: cs, pendingDash =>
    match toSlugAlphaNum? c with
    | some lc =>
      if pendingDash then '-' :: lc :: slugCharsAux cs false
      else lc :: slugCharsAux cs false
    | none =>
      slugCharsAux cs true

def slugCharsStart : List Char → List Char
  | [] => []
  | c :: cs =>
    match toSlugAlphaNum? c with
    | some lc => lc :: slugCharsAux cs false
    | none => slugCharsStart cs

/-- Total, deterministic heading slugifier; defaults to `"section"` when input has no ASCII alphanumerics. -/
def slugify (raw : String) : String :=
  match slugCharsStart raw.toList with
  | [] => "section"
  | cs => String.ofList cs

/-- Extract `##` and `###` headings into the right-rail table of contents. -/
def tocFromBlocks : List Block → List TocItem
  | [] => []
  | .heading lvl slug _ plain :: rest =>
    if lvl == 2 || lvl == 3 then
      { level := lvl, slug, title := plain } :: tocFromBlocks rest
    else
      tocFromBlocks rest
  | _ :: rest => tocFromBlocks rest

end LakeportMdx
