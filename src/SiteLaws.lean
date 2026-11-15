import State
/-!
# `Site.Laws` — Kernel-Checked Navigation & Cache Coherence (`[proof-only, 0 B C]`)

Strictly `theorem`-only module verifying URL round-trips, `MemoCell` coherence after
`syncCaches`, and monotonic `commit` progression.
-/
namespace Site.Laws
open LakeportRouter LakeportStyle Site Site.Docs

theorem parseSiteUrl_routePath (r : SiteRoute) :
    parseSiteUrl (routePath r) = r := by
  cases r with
  | docsPage s => cases s <;> decide
  | _ => decide

theorem syncCaches_sandbox_coherent (s : AppState) :
    (syncCaches s).sandboxCache.get = LakeportMdx.parseMdx s.sandboxSource := by
  simp [syncCaches]

theorem syncCaches_docsPage_coherent (s : AppState) (slug : DocSlug)
    (hRoute : s.router.activeRoute = .docsPage slug) :
    (syncCaches s).docCache.get = parseDocSlug slug := by
  simp [syncCaches, hRoute]

theorem bump_increments_commit (s : AppState) :
    (bump s).commit = s.commit + 1 := by
  rfl

theorem copySnippet_emits_clipboardWrite (s : AppState) (key code : String) :
    (copySnippet s key code).2 = [LakeportEffects.EffectReq.clipboardWrite s.nextReqId code] := by
  rfl

end Site.Laws
