import LakeportRouter
import Docs.CatalogGen
/-!
# `Routes` : Typed Marketing & Documentation URL Codec

Maps every marketing page and documentation chapter to its canonical URL path
and proves `LawfulUrlCodec routeCodec` so links and SSG routes never drift.
-/
namespace Site
open LakeportRouter Site.Docs

inductive SiteRoute where
  | home
  | whyLean
  | ecosystem
  | showcase
  | docsIndex
  | docsPage (slug : DocSlug)
  deriving DecidableEq, Repr, Inhabited

namespace DocSlug

theorem parse_slug (s : DocSlug) : DocSlug.parse? s.slug = some s := by
  cases s <;> rfl

end DocSlug

def routeCodec : UrlCodec SiteRoute where
  toSegments
    | .home => []
    | .whyLean => ["why-lean"]
    | .ecosystem => ["ecosystem"]
    | .showcase => ["showcase"]
    | .docsIndex => ["docs"]
    | .docsPage s => ["docs", s.slug]
  ofSegments
    | [] => some .home
    | ["why-lean"] => some .whyLean
    | ["ecosystem"] => some .ecosystem
    | ["showcase"] => some .showcase
    | ["docs"] => some .docsIndex
    | ["docs", raw] => (DocSlug.parse? raw).map .docsPage
    | _ => none

instance : LawfulUrlCodec routeCodec where
  ofSegments_toSegments := by
    intro r
    cases r with
    | home => rfl
    | whyLean => rfl
    | ecosystem => rfl
    | showcase => rfl
    | docsIndex => rfl
    | docsPage s => simp [routeCodec, DocSlug.parse_slug]

def classifyRoute : SiteRoute → Presentation
  | _ => .tab

def routePath (r : SiteRoute) : String :=
  routeCodec.formatPath r

def parseSiteUrl (raw : String) : SiteRoute :=
  (routeCodec.parseUrl raw).getD .home

end Site
