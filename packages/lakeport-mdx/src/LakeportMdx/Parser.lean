import LakeportMdx.Ast
/-!
# `LakeportMdx.Parser` — Total Pure-Lean MDX Parser

Parses `.mdx` source strings into `MdxDoc` (frontmatter, blocks, and table of contents)
using fuel-bounded total recursion (`0` `partial`, `0` `unsafe`, `0` `sorry`).
-/
namespace LakeportMdx

private def isWs (c : Char) : Bool :=
  c == ' ' || c == '\t' || c == '\r' || c == '\n'

private def trimAscii (s : String) : String :=
  let cs := s.toList.dropWhile isWs
  String.ofList ((cs.reverse.dropWhile isWs).reverse)

private def stripQuotes (s : String) : String :=
  let t := trimAscii s
  if t.length >= 2 && t.startsWith "\"" && t.endsWith "\"" then
    String.ofList ((t.toList.drop 1).dropLast)
  else
    t

private def parseNatDefault (s : String) (dflt : Nat) : Nat :=
  let cs := (trimAscii s).toList
  if cs.isEmpty then dflt
  else
    cs.foldl (fun acc c =>
      if c >= '0' && c <= '9' then acc * 10 + (c.toNat - '0'.toNat) else acc) 0

private def parseFrontmatterLines : List String → Frontmatter → Frontmatter
  | [], fm => fm
  | line :: rest, fm =>
    let parts := line.splitOn ":"
    match parts with
    | keyRaw :: valParts =>
      if valParts.isEmpty then
        parseFrontmatterLines rest fm
      else
        let key := trimAscii keyRaw
        let val := stripQuotes (":".intercalate valParts)
        let fm' :=
          if key == "title" then { fm with title := val }
          else if key == "summary" then { fm with summary := val }
          else if key == "section" then { fm with sectionName := val }
          else if key == "order" then { fm with order := parseNatDefault val fm.order }
          else if key == "readingMinutes" then { fm with readingMinutes := parseNatDefault val fm.readingMinutes }
          else if key == "updated" then { fm with updated := val }
          else fm
        parseFrontmatterLines rest fm'
    | [] => parseFrontmatterLines rest fm

/-- Extract optional leading `--- ... ---` frontmatter block and remaining body lines. -/
def splitFrontmatter (lines : List String) : Frontmatter × List String :=
  match lines with
  | first :: rest =>
    if trimAscii first == "---" then
      let rec collect (acc : List String) : List String → Frontmatter × List String
        | [] => ({}, lines)
        | l :: ls =>
          if trimAscii l == "---" then
            (parseFrontmatterLines acc.reverse {}, ls)
          else
            collect (l :: acc) ls
      collect [] rest
    else
      ({}, lines)
  | [] => ({}, [])

/-! ## Inline Span Parser (`**strong**`, `*em*`, `` `code` ``, `[label](href)`) -/

private def findClosingSingle (delim : Char) : List Char → Option (List Char × List Char)
  | [] => none
  | c :: cs =>
    if c == delim then some ([], cs)
    else
      match findClosingSingle delim cs with
      | some (inside, rest) => some (c :: inside, rest)
      | none => none

private def findClosingDouble (d1 d2 : Char) : List Char → Option (List Char × List Char)
  | [] => none
  | [ _ ] => none
  | a :: b :: cs =>
    if a == d1 && b == d2 then some ([], cs)
    else
      match findClosingDouble d1 d2 (b :: cs) with
      | some (inside, rest) => some (a :: inside, rest)
      | none => none

private def flushText (revChars : List Char) (acc : List Inline) : List Inline :=
  if revChars.isEmpty then acc
  else .text (String.ofList revChars.reverse) :: acc

private def flushStrong (revChars : List Char) (acc : List Inline) : List Inline :=
  if revChars.isEmpty then acc
  else .strong (String.ofList revChars.reverse) :: acc

private def splitBoldCodeAux : Nat → List Char → List Char → List Inline → List Inline
  | 0, rem, textRev, acc =>
    (flushStrong (rem.reverse ++ textRev) acc).reverse
  | _ + 1, [], textRev, acc =>
    (flushStrong textRev acc).reverse
  | fuel + 1, '`' :: cs, textRev, acc =>
    match findClosingSingle '`' cs with
    | some (codeCs, rest) =>
      let acc' := .code (String.ofList codeCs) :: flushStrong textRev acc
      splitBoldCodeAux fuel rest [] acc'
    | none =>
      splitBoldCodeAux fuel cs ('`' :: textRev) acc
  | fuel + 1, c :: cs, textRev, acc =>
    splitBoldCodeAux fuel cs (c :: textRev) acc

private def parseInlinesAux : Nat → List Char → List Char → List Inline → List Inline
  | 0, rem, textRev, acc =>
    (flushText (rem.reverse ++ textRev) acc).reverse
  | _ + 1, [], textRev, acc =>
    (flushText textRev acc).reverse
  | fuel + 1, '`' :: cs, textRev, acc =>
    match findClosingSingle '`' cs with
    | some (codeCs, rest) =>
      let acc' := .code (String.ofList codeCs) :: flushText textRev acc
      parseInlinesAux fuel rest [] acc'
    | none =>
      parseInlinesAux fuel cs ('`' :: textRev) acc
  | fuel + 1, '*' :: '*' :: cs, textRev, acc =>
    match findClosingDouble '*' '*' cs with
    | some (boldCs, rest) =>
      let boldSpans := splitBoldCodeAux (boldCs.length + 1) boldCs [] []
      let acc' := boldSpans.reverse ++ flushText textRev acc
      parseInlinesAux fuel rest [] acc'
    | none =>
      parseInlinesAux fuel cs ('*' :: '*' :: textRev) acc
  | fuel + 1, '*' :: cs, textRev, acc =>
    match findClosingSingle '*' cs with
    | some (emCs, rest) =>
      let acc' := .em (String.ofList emCs) :: flushText textRev acc
      parseInlinesAux fuel rest [] acc'
    | none =>
      parseInlinesAux fuel cs ('*' :: textRev) acc
  | fuel + 1, '[' :: cs, textRev, acc =>
    match findClosingSingle ']' cs with
    | some (labelCs, '(' :: afterBracket) =>
      match findClosingSingle ')' afterBracket with
      | some (hrefCs, rest) =>
        let acc' := .link (String.ofList labelCs) (String.ofList hrefCs) :: flushText textRev acc
        parseInlinesAux fuel rest [] acc'
      | none =>
        parseInlinesAux fuel cs ('[' :: textRev) acc
    | _ =>
      parseInlinesAux fuel cs ('[' :: textRev) acc
  | fuel + 1, c :: cs, textRev, acc =>
    parseInlinesAux fuel cs (c :: textRev) acc

/-- Parse inline MDX formatting spans (`code`, `strong`, `em`, `link`). -/
def parseInlines (s : String) : List Inline :=
  let cs := s.toList
  parseInlinesAux (cs.length + 1) cs [] []

/-! ## JSX Prop & Fence Header Helpers -/

private def parsePropsChars : Nat → List Char → List (String × String)
  | 0, _ => []
  | _ + 1, [] => []
  | fuel + 1, c :: cs =>
    if c == ' ' || c == '\t' || c == '/' || c == '>' then
      parsePropsChars fuel cs
    else
      let rec takeKey : List Char → List Char × List Char
        | [] => ([], [])
        | k :: ks =>
          if k == '=' || k == ' ' || k == '>' || k == '/' then ([], k :: ks)
          else
            let (p, s) := takeKey ks
            (k :: p, s)
      let (kCs, afterK) := takeKey (c :: cs)
      match afterK with
      | '=' :: '\"' :: valStart =>
        match findClosingSingle '\"' valStart with
        | some (vCs, rest) =>
          (String.ofList kCs, String.ofList vCs) :: parsePropsChars fuel rest
        | none => []
      | rest => parsePropsChars fuel rest

/-- Parse `key="value"` attributes on an embedded JSX component tag or code fence. -/
def parseProps (raw : String) : List (String × String) :=
  let cs := raw.toList
  parsePropsChars (cs.length + 1) cs

private def parseFenceInfo (raw : String) : String × String :=
  let t := trimAscii raw
  let parts := t.splitOn " "
  match parts with
  | [] => ("text", "")
  | lang :: rest =>
    let props := parseProps (" ".intercalate rest)
    let title := match props.find? (fun (k, _) => k == "title") with
      | some (_, v) => v
      | none => ""
    (if lang.isEmpty then "text" else lang, title)

private def isOrderedItemLine? (t : String) : Option String :=
  let cs := t.toList
  let rec dropDigits : List Char → Bool → Option (List Char)
    | [], _ => none
    | '.' :: ' ' :: rest, true => some rest
    | c :: rest, seen =>
      if c >= '0' && c <= '9' then dropDigits rest true else none
  (dropDigits cs false).map String.ofList

private def isTableSepLine (t : String) : Bool :=
  t.startsWith "|" && t.toList.all (fun c => c == '|' || c == '-' || c == ':' || c == ' ' || c == '\t')

private def splitTableCells (line : String) : List String :=
  let t := trimAscii line
  let inner :=
    let s1 := if t.startsWith "|" then String.ofList (t.toList.drop 1) else t
    if s1.endsWith "|" then String.ofList s1.toList.dropLast else s1
  (inner.splitOn "|").map trimAscii

private def isSelfClosingJsx? (t : String) : Option (String × List (String × String)) :=
  if t.startsWith "<" && t.endsWith "/>" then
    let inner := trimAscii (String.ofList ((t.toList.drop 1).dropLast.dropLast))
    let parts := inner.splitOn " "
    match parts with
    | nm :: rest =>
      match nm.toList with
      | c :: _ =>
        if c >= 'A' && c <= 'Z' then
          some (nm, parseProps (" ".intercalate rest))
        else none
      | [] => none
    | [] => none
  else none

private def isCalloutOpen? (t : String) : Option (CalloutKind × String) :=
  if t.startsWith "<Callout" && t.endsWith ">" && !t.endsWith "/>" then
    let inner := String.ofList ((t.toList.drop 8).dropLast)
    let props := parseProps inner
    let kind := match props.find? (fun (k, _) => k == "kind") with
      | some (_, v) => CalloutKind.ofString v
      | none => .note
    let title := match props.find? (fun (k, _) => k == "title") with
      | some (_, v) => v
      | none => kind.defaultTitle
    some (kind, title)
  else none

private def takeUntilFence : List String → List String → List String × List String
  | acc, [] => (acc.reverse, [])
  | acc, l :: ls =>
    if (trimAscii l).startsWith "```" then (acc.reverse, ls)
    else takeUntilFence (l :: acc) ls

private def groupParagraphs : List String → List String → List (List Inline)
  | curRev, [] =>
    if curRev.isEmpty then []
    else [parseInlines (" ".intercalate curRev.reverse)]
  | curRev, l :: ls =>
    let t := trimAscii l
    if t.isEmpty then
      if curRev.isEmpty then groupParagraphs [] ls
      else parseInlines (" ".intercalate curRev.reverse) :: groupParagraphs [] ls
    else
      groupParagraphs (t :: curRev) ls

private def takeUntilCalloutClose : List String → List String → List String × List String
  | acc, [] => (acc.reverse, [])
  | acc, l :: ls =>
    if trimAscii l == "</Callout>" then (acc.reverse, ls)
    else takeUntilCalloutClose (l :: acc) ls

private def takeBullets : List String → List (List Inline) × List String
  | [] => ([], [])
  | l :: ls =>
    let t := trimAscii l
    if t.startsWith "- " then
      let item := parseInlines (String.ofList (t.toList.drop 2))
      let (more, rest) := takeBullets ls
      (item :: more, rest)
    else
      ([], l :: ls)

private def takeOrdered : List String → List (List Inline) × List String
  | [] => ([], [])
  | l :: ls =>
    match isOrderedItemLine? (trimAscii l) with
    | some body =>
      let (more, rest) := takeOrdered ls
      (parseInlines body :: more, rest)
    | none => ([], l :: ls)

private def takeTableRows : List String → List (List (List Inline)) × List String
  | [] => ([], [])
  | l :: ls =>
    let t := trimAscii l
    if t.startsWith "|" then
      let row := (splitTableCells t).map parseInlines
      let (more, rest) := takeTableRows ls
      (row :: more, rest)
    else
      ([], l :: ls)

private def takeQuoteLines : List String → List String × List String
  | [] => ([], [])
  | l :: ls =>
    let t := trimAscii l
    if t.startsWith "> " then
      let (more, rest) := takeQuoteLines ls
      (String.ofList (t.toList.drop 2) :: more, rest)
    else if t == ">" then
      let (more, rest) := takeQuoteLines ls
      ("" :: more, rest)
    else
      ([], l :: ls)

private def isBlockStarter (t : String) : Bool :=
  t.isEmpty ||
  t.startsWith "#" ||
  t.startsWith "```" ||
  t.startsWith "- " ||
  (isOrderedItemLine? t).isSome ||
  t.startsWith "|" ||
  t.startsWith "> " ||
  t == "---" ||
  (isCalloutOpen? t).isSome ||
  (isSelfClosingJsx? t).isSome

private def takeParagraphLines : List String → List String × List String
  | [] => ([], [])
  | l :: ls =>
    let t := trimAscii l
    if isBlockStarter t then ([], l :: ls)
    else
      let (more, rest) := takeParagraphLines ls
      (t :: more, rest)

private def parseHeadingLine? (t : String) : Option Block :=
  if t.startsWith "### " then
    let raw := trimAscii (String.ofList (t.toList.drop 4))
    let inls := parseInlines raw
    let plain := inlinesPlain inls
    some (.heading 3 (slugify plain) inls plain)
  else if t.startsWith "## " then
    let raw := trimAscii (String.ofList (t.toList.drop 3))
    let inls := parseInlines raw
    let plain := inlinesPlain inls
    some (.heading 2 (slugify plain) inls plain)
  else if t.startsWith "# " then
    let raw := trimAscii (String.ofList (t.toList.drop 2))
    let inls := parseInlines raw
    let plain := inlinesPlain inls
    some (.heading 1 (slugify plain) inls plain)
  else none

private def parseBlocksAux : Nat → List String → List Block
  | 0, _ => []
  | _ + 1, [] => []
  | fuel + 1, l :: ls =>
    let t := trimAscii l
    if t.isEmpty then
      parseBlocksAux fuel ls
    else if t == "---" then
      .thematicBreak :: parseBlocksAux fuel ls
    else if let some h := parseHeadingLine? t then
      h :: parseBlocksAux fuel ls
    else if t.startsWith "```" then
      let info := String.ofList (t.toList.drop 3)
      let (lang, title) := parseFenceInfo info
      let (codeLines, rest) := takeUntilFence [] ls
      .codeBlock lang title ("\n".intercalate codeLines) :: parseBlocksAux fuel rest
    else if let some (kind, title) := isCalloutOpen? t then
      let (bodyLines, rest) := takeUntilCalloutClose [] ls
      .callout kind title (groupParagraphs [] bodyLines) :: parseBlocksAux fuel rest
    else if let some (compName, props) := isSelfClosingJsx? t then
      .component compName props :: parseBlocksAux fuel ls
    else if t.startsWith "- " then
      let (items, rest) := takeBullets (l :: ls)
      .bulletList items :: parseBlocksAux fuel rest
    else if (isOrderedItemLine? t).isSome then
      let (items, rest) := takeOrdered (l :: ls)
      .orderedList items :: parseBlocksAux fuel rest
    else if t.startsWith "|" then
      match ls with
      | sep :: afterSep =>
        if isTableSepLine (trimAscii sep) then
          let headers := splitTableCells t
          let (rows, rest) := takeTableRows afterSep
          .table headers rows :: parseBlocksAux fuel rest
        else
          let (pLines, rest) := takeParagraphLines (ls)
          .paragraph (parseInlines (" ".intercalate (t :: pLines))) :: parseBlocksAux fuel rest
      | [] =>
        [.paragraph (parseInlines t)]
    else if t.startsWith "> " then
      let (qLines, rest) := takeQuoteLines (l :: ls)
      .blockquote (parseInlines (" ".intercalate qLines)) :: parseBlocksAux fuel rest
    else
      let (pLines, rest) := takeParagraphLines (l :: ls)
      let joined := " ".intercalate (if pLines.isEmpty then [t] else pLines)
      .paragraph (parseInlines joined) :: parseBlocksAux fuel rest

/-- Parse a complete `.mdx` source string into frontmatter, AST blocks, and right-rail TOC. -/
def parseMdx (raw : String) : MdxDoc :=
  let clean := raw.replace "\r\n" "\n"
  let rawLines := clean.splitOn "\n"
  let (fm, bodyLines) := splitFrontmatter rawLines
  let blocks := parseBlocksAux (bodyLines.length + 1) bodyLines
  { frontmatter := fm, blocks := blocks, toc := tocFromBlocks blocks }

end LakeportMdx
