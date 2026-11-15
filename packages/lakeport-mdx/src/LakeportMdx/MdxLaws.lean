import LakeportMdx.Ast
import LakeportMdx.Highlight
import LakeportMdx.Parser
/-!
# `LakeportMdx.MdxLaws` — Kernel-Checked MDX Invariants (`[proof-only, 0 B C]`)

Strictly `theorem`-only module verifying:
1. `slugify` always produces non-empty slugs containing only `[a-z0-9-]` (`slugify_safe`).
2. `tocFromBlocks` emits only `h2` and `h3` headings (`tocFromBlocks_levels`).
3. `parseMdx` maintains exact coherence between `doc.toc` and `doc.blocks` (`parseMdx_toc_coherent`).
-/
namespace LakeportMdx.Laws
open LakeportMdx

theorem asciiUpperToLower_isSlugChar {c out : Char} (h : asciiUpperToLower? c = some out) :
    isSlugChar out = true := by
  unfold asciiUpperToLower? at h
  split at h <;> cases h <;> decide

theorem toSlugAlphaNum_isSlugChar {c out : Char} (h : toSlugAlphaNum? c = some out) :
    isSlugChar out = true := by
  unfold toSlugAlphaNum? at h
  split at h
  · cases h
    rename_i h1
    simp [isSlugChar, h1]
  · split at h
    · cases h
      rename_i _ h2
      simp [isSlugChar, h2]
    · exact asciiUpperToLower_isSlugChar h

theorem slugCharsAux_valid :
    ∀ (cs : List Char) (p : Bool) (x : Char), x ∈ slugCharsAux cs p → isSlugChar x = true
  | [], _, _, hx => by cases hx
  | c :: cs, p, x, hx => by
    unfold slugCharsAux at hx
    cases hOpt : toSlugAlphaNum? c with
    | none =>
      rw [hOpt] at hx
      exact slugCharsAux_valid cs true x hx
    | some lc =>
      rw [hOpt] at hx
      cases p with
      | false =>
        simp at hx
        rcases hx with rfl | hTail
        · exact toSlugAlphaNum_isSlugChar hOpt
        · exact slugCharsAux_valid cs false x hTail
      | true =>
        simp at hx
        rcases hx with rfl | rfl | hTail
        · rfl
        · exact toSlugAlphaNum_isSlugChar hOpt
        · exact slugCharsAux_valid cs false x hTail

theorem slugCharsStart_valid :
    ∀ (cs : List Char) (x : Char), x ∈ slugCharsStart cs → isSlugChar x = true
  | [], _, hx => by cases hx
  | c :: cs, x, hx => by
    unfold slugCharsStart at hx
    cases hOpt : toSlugAlphaNum? c with
    | none =>
      rw [hOpt] at hx
      exact slugCharsStart_valid cs x hx
    | some lc =>
      rw [hOpt] at hx
      simp at hx
      rcases hx with rfl | hTail
      · exact toSlugAlphaNum_isSlugChar hOpt
      · exact slugCharsAux_valid cs false x hTail

theorem slugify_safe (raw : String) : SafeSlug (slugify raw) := by
  unfold SafeSlug slugify
  cases hStart : slugCharsStart raw.toList with
  | nil =>
    constructor
    · decide
    · intro c hc
      change c ∈ ['s', 'e', 'c', 't', 'i', 'o', 'n'] at hc
      rcases List.mem_cons.mp hc with rfl | hc1
      · decide
      · rcases List.mem_cons.mp hc1 with rfl | hc2
        · decide
        · rcases List.mem_cons.mp hc2 with rfl | hc3
          · decide
          · rcases List.mem_cons.mp hc3 with rfl | hc4
            · decide
            · rcases List.mem_cons.mp hc4 with rfl | hc5
              · decide
              · rcases List.mem_cons.mp hc5 with rfl | hc6
                · decide
                · rcases List.mem_cons.mp hc6 with rfl | hc7
                  · decide
                  · cases hc7
  | cons hd tl =>
    constructor
    · simp
    · intro c hc
      rw [String.toList_ofList] at hc
      have hMem : c ∈ slugCharsStart raw.toList := by
        rw [hStart]
        exact hc
      exact slugCharsStart_valid raw.toList c hMem

theorem tocFromBlocks_levels :
    ∀ (bs : List Block) (item : TocItem), item ∈ tocFromBlocks bs → item.level = 2 ∨ item.level = 3
  | [], _, h => by cases h
  | b :: rest, item, h => by
    cases b with
    | heading lvl slug inls plain =>
      simp only [tocFromBlocks] at h
      split at h
      · rename_i hCond
        simp only [List.mem_cons] at h
        rcases h with rfl | hMore
        · simp only [Bool.or_eq_true, beq_iff_eq] at hCond
          exact hCond
        · exact tocFromBlocks_levels rest item hMore
      · exact tocFromBlocks_levels rest item h
    | _ =>
      simp only [tocFromBlocks] at h
      exact tocFromBlocks_levels rest item h

theorem parseMdx_toc_coherent (raw : String) :
    (parseMdx raw).toc = tocFromBlocks (parseMdx raw).blocks := by
  rfl

end LakeportMdx.Laws
