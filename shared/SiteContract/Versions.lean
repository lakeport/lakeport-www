/-!
# Published Edge Protocol Inventory (`SiteContract.Versions`)

Pure `Init`-only version and capability definitions shared by client and server.
Wire contract versions (`lpw1`, `lpw2`), persistence schemas, and application
release numbers are distinct identities.
-/
namespace Site.Contract

inductive Version where
  | v1
  | v2
  deriving DecidableEq, Repr, Inhabited

def Version.slug : Version → String
  | .v1 => "lpw1"
  | .v2 => "lpw2"

def Version.parse : String → Option Version
  | "lpw1" => some .v1
  | "lpw2" => some .v2
  | _ => none

inductive Capability where
  | instantRelease
  | auditReceipt
  | batchSettle
  deriving DecidableEq, Repr, Inhabited

def Capability.slug : Capability → String
  | .instantRelease => "instant_release"
  | .auditReceipt => "audit_receipt"
  | .batchSettle => "batch_settle"

def Capability.parse : String → Option Capability
  | "instant_release" => some .instantRelease
  | "audit_receipt" => some .auditReceipt
  | "batch_settle" => some .batchSettle
  | _ => none

structure Advertisement where
  versions : List Version
  capabilities : List Capability
  deriving DecidableEq, Repr, Inhabited

/-- Legacy production server still running `lpw1` only (zero optional capabilities). -/
def legacyServerAd : Advertisement :=
  { versions := [.v1], capabilities := [] }

/-- Staged dual-version server serving `lpw1` and `lpw2` before instant release is enabled. -/
def dualServerBaselineAd : Advertisement :=
  { versions := [.v1, .v2], capabilities := [.auditReceipt] }

/-- Full `lpw2` server advertising negotiated `instant_release` and `audit_receipt`. -/
def fullV2ServerAd : Advertisement :=
  { versions := [.v1, .v2], capabilities := [.instantRelease, .auditReceipt, .batchSettle] }

def splitCommaChars : List Char → List Char → List String
  | [], curRev => [String.ofList curRev.reverse]
  | ',' :: rest, curRev => String.ofList curRev.reverse :: splitCommaChars rest []
  | c :: rest, curRev => splitCommaChars rest (c :: curRev)

def parseCommaList {α : Type} (parseOne : String → Option α) (raw : String) : Option (List α) :=
  if raw.toList.isEmpty then some []
  else (splitCommaChars raw.toList []).mapM parseOne

def encodeCommaList {α : Type} (fmt : α → String) (xs : List α) : String :=
  ",".intercalate (xs.map fmt)

/-- Canonical `GET /api/capabilities` fields (`CAPS \t 1 \t <versions> \t <capabilities>`). -/
def encodeAdvertisementFields (ad : Advertisement) : List String :=
  ["CAPS", "1", encodeCommaList Version.slug ad.versions, encodeCommaList Capability.slug ad.capabilities]

/-- Fail-closed parser: unknown schema numbers, unknown version or capability names,
    missing fields, and empty version inventories all return `none`. -/
def parseAdvertisement : List String → Option Advertisement
  | ["CAPS", "1", versionsRaw, capsRaw] => do
    let vs ← parseCommaList Version.parse versionsRaw
    if vs.isEmpty then none
    else
      let cs ← parseCommaList Capability.parse capsRaw
      pure { versions := vs, capabilities := cs }
  | _ => none

end Site.Contract
