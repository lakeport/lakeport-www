/-!
# `LakeportMdx.Highlight` — Pure Lossless Syntax Highlighter

Tokenizes `lean`, `lp`, `toml`, and `sh` source lines in pure Lean (`Init` only)
without JavaScript highlighting libraries. Every line's token slices concatenate
back to the exact source line (`tokensText_highlightLine` in `MdxLaws.lean`).
-/
namespace LakeportMdx

inductive TokKind where
  | plain
  | keyword
  | typeName
  | decl
  | stringLit
  | comment
  | tag
  | attr
  | number
  deriving DecidableEq, Repr, Inhabited

def leanKeywords : List String := [
  "import", "import_css", "from", "namespace", "end", "open", "def", "abbrev",
  "theorem", "lemma", "structure", "inductive", "class", "instance", "where",
  "deriving", "match", "with", "if", "then", "else", "let", "mut", "do",
  "return", "pure", "for", "in", "by", "rfl", "simp", "cases", "intro",
  "exact", "fun", "private", "protected", "noncomputable", "true", "false",
  "some", "none", "set_option"
]

def leanBuiltins : List String := [
  "Nat", "Int", "Bool", "String", "Char", "Unit", "List", "Array", "Option",
  "Except", "Prop", "Type", "StyledView", "StyledApp", "ClassName", "UrlCodec",
  "LawfulUrlCodec", "RouterState", "RouterShell", "EffectReq", "EffectResp",
  "MemoCell", "MemoKeyedList", "Version", "Capability", "Advertisement",
  "Request", "Response", "Handler", "Gate"
]

def shKeywords : List String := [
  "lakeport", "lake", "git", "curl", "export", "cd", "mkdir", "npm", "npx",
  "check", "build", "dev", "test", "doctor", "mcp", "web", "--release"
]

def isIdentInit (c : Char) : Bool :=
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'

def isIdentRest (c : Char) : Bool :=
  isIdentInit c || (c >= '0' && c <= '9') || c == '\'' || c == '?' || c == '!' || c == '-'

def isDigitChar (c : Char) : Bool :=
  c >= '0' && c <= '9'

/-- Split `cs` into `(prefix satisfying p, remainder)` with structural proof-friendly definition. -/
def spanChars (p : Char → Bool) : List Char → List Char × List Char
  | [] => ([], [])
  | c :: cs =>
    if p c then
      let (pre, suf) := spanChars p cs
      (c :: pre, suf)
    else
      ([], c :: cs)

/-- Scan the body of a quoted string literal after the opening `quoteChar`. -/
def scanQuoted (quoteChar : Char) : List Char → List Char × List Char
  | [] => ([], [])
  | '\\' :: c :: cs =>
    let (pre, suf) := scanQuoted quoteChar cs
    ('\\' :: c :: pre, suf)
  | c :: cs =>
    if c == quoteChar then
      ([c], cs)
    else
      let (pre, suf) := scanQuoted quoteChar cs
      (c :: pre, suf)

def classifyWord (lang : String) (w : String) : TokKind :=
  if lang == "sh" || lang == "bash" || lang == "shell" then
    if shKeywords.contains w then .keyword
    else if w.startsWith "--" || w.startsWith "-" then .attr
    else .plain
  else if lang == "toml" then
    if w == "true" || w == "false" then .keyword else .attr
  else
    if leanKeywords.contains w then
      if w == "theorem" || w == "def" || w == "structure" || w == "inductive" || w == "instance" then .decl
      else .keyword
    else if leanBuiltins.contains w then .typeName
    else match w.toList with
      | c :: _ => if c >= 'A' && c <= 'Z' then .typeName else .plain
      | [] => .plain

/-- Fuel-bounded lossless tokenizer on `List Char`. When fuel reaches `0`, emits remaining chars as `.plain`. -/
def tokenizeChars (lang : String) : Nat → List Char → List (TokKind × List Char)
  | 0, [] => []
  | 0, cs => [(.plain, cs)]
  | _ + 1, [] => []
  | fuel + 1, '-' :: '-' :: cs =>
    if lang == "lean" || lang == "lp" then
      [(.comment, '-' :: '-' :: cs)]
    else
      let (rest, after) := spanChars isIdentRest cs
      let full := '-' :: '-' :: rest
      (classifyWord lang (String.ofList full), full) :: tokenizeChars lang fuel after
  | fuel + 1, '#' :: cs =>
    if lang == "toml" || lang == "sh" || lang == "bash" || lang == "shell" then
      [(.comment, '#' :: cs)]
    else
      (.plain, ['#']) :: tokenizeChars lang fuel cs
  | fuel + 1, '"' :: cs =>
    let (body, after) := scanQuoted '"' cs
    (.stringLit, '"' :: body) :: tokenizeChars lang fuel after
  | fuel + 1, '<' :: '/' :: c :: cs =>
    if lang == "lp" && isIdentInit c then
      let (nm, after) := spanChars isIdentRest cs
      (.tag, '<' :: '/' :: c :: nm) :: tokenizeChars lang fuel after
    else
      (.plain, ['<', '/', c]) :: tokenizeChars lang fuel cs
  | fuel + 1, '<' :: c :: cs =>
    if lang == "lp" && isIdentInit c then
      let (nm, after) := spanChars isIdentRest cs
      (.tag, '<' :: c :: nm) :: tokenizeChars lang fuel after
    else
      (.plain, ['<', c]) :: tokenizeChars lang fuel cs
  | fuel + 1, c :: cs =>
    if isIdentInit c then
      let (rest, after) := spanChars isIdentRest cs
      let w := String.ofList (c :: rest)
      (classifyWord lang w, c :: rest) :: tokenizeChars lang fuel after
    else if isDigitChar c then
      let (rest, after) := spanChars isDigitChar cs
      (.number, c :: rest) :: tokenizeChars lang fuel after
    else
      let (ws, after) := spanChars (fun ch => ch == ' ' || ch == '\t') (c :: cs)
      match ws with
      | _ :: _ => (.plain, ws) :: tokenizeChars lang fuel after
      | [] => (.plain, [c]) :: tokenizeChars lang fuel cs

/-- Highlight a single line into `(TokKind × String)` tokens. -/
def highlightLine (lang : String) (line : String) : List (TokKind × String) :=
  let cs := line.toList
  (tokenizeChars lang (cs.length + 1) cs).map (fun (k, seg) => (k, String.ofList seg))

/-- Reconstruct raw text from a highlighted line's token list. -/
def tokensText (toks : List (TokKind × String)) : String :=
  String.join (toks.map Prod.snd)

/-- Highlight a multi-line code block line by line. -/
def highlightCode (lang : String) (code : String) : List (List (TokKind × String)) :=
  (code.splitOn "
").map (highlightLine lang)

end LakeportMdx
