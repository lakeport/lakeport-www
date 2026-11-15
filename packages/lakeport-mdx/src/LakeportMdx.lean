import LakeportMdx.Ast
import LakeportMdx.Highlight
import LakeportMdx.Parser
import LakeportMdx.Render
/-!
# `LakeportMdx` — Reservoir-Ready Pure-Lean MDX Package

Re-exports the AST, lossless syntax highlighter, total MDX parser, and scoped
`LakeportStyle.StyledView` renderer. Proof laws live in `LakeportMdx.MdxLaws`
(`[proof-only, 0 B C]`) so zero proof machinery enters compiled C or WebAssembly.
-/
