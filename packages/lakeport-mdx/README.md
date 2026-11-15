# lakeport-mdx

Pure-Lean MDX parser, frontmatter reader, lossless syntax highlighter, and `LakeportStyle.StyledView` renderer designed for Reservoir distribution.

## Capabilities

- YAML-subset frontmatter (`title`, `summary`, `section`, `order`, `readingMinutes`, `updated`)
- Total heading slugifier (`SafeSlug` proved in `LakeportMdx.MdxLaws`) and automatic table-of-contents extraction
- Lossless syntax highlighting for `lean`, `lp`, `toml`, and `sh` (`tokensText_highlightLine` proved in `LakeportMdx.MdxLaws`)
- Scoped CSS module (`Mdx.css`) with zero global selector collisions
- Embedded Lakeport JSX component slots (`<Callout>`, `<ContractSimulator />`, `<RolloutTimeline />`, `<DeadCodeExplorer />`, or custom tags)

## Dead-code elimination

 Proof theorems live in `LakeportMdx/MdxLaws.lean` (`[proof-only, 0 B C]`). Consumers that import `LakeportMdx` link only the AST, parser, highlighter, and view functions they actually reach from `App.app`.
