import LakeportMdx.Ast
import LakeportMdx.Parser
import Docs.CatalogGen
/-!
# `Site.Docs.Registry` : Section Grouping, Prev/Next Links & Instant Search

Pure helpers over `DocSlug` and `LakeportMdx.parseMdx` for sidebar navigation,
instant search filtering, and sequential prev/next chapter links.
-/
namespace Site.Docs
open LakeportMdx

def parseDocSlug (s : DocSlug) : MdxDoc :=
  parseMdx s.rawMdx

def sectionsOrder : List String := [
  "Getting started",
  "Recommended patterns",
  "Building interfaces",
  "Ecosystem and tooling"
]

def docsInSection (sec : String) : List DocSlug :=
  DocSlug.all.filter (fun d => d.sectionName == sec)

private def toLowerAscii (s : String) : String :=
  String.ofList (s.toList.map fun c =>
    if c >= 'A' && c <= 'Z' then Char.ofNat (c.toNat - 'A'.toNat + 'a'.toNat) else c)

private def trimWs (s : String) : String :=
  let isWs (c : Char) : Bool := c == ' ' || c == '\t' || c == '\r' || c == '\n'
  let cs := s.toList.dropWhile isWs
  String.ofList ((cs.reverse.dropWhile isWs).reverse)

private def containsCaseInsensitive (haystack needle : String) : Bool :=
  if needle.isEmpty then true
  else
    let h := toLowerAscii haystack
    let n := toLowerAscii needle
    (h.splitOn n).length > 1

def matchesDocQuery (query : String) (d : DocSlug) : Bool :=
  let q := trimWs query
  if q.isEmpty then true
  else
    containsCaseInsensitive d.title q ||
    containsCaseInsensitive d.summary q ||
    containsCaseInsensitive d.sectionName q ||
    containsCaseInsensitive d.slug q

private def neighborsAux (target : DocSlug) (prev : Option DocSlug) :
    List DocSlug → Option DocSlug × Option DocSlug
  | [] => (none, none)
  | x :: rest =>
    if x == target then (prev, rest.head?)
    else neighborsAux target (some x) rest

/-- Return `(previousChapter?, nextChapter?)` in reading order. -/
def neighbors (target : DocSlug) : Option DocSlug × Option DocSlug :=
  neighborsAux target none DocSlug.all

end Site.Docs
