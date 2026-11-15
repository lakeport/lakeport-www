import SiteContract.Versions
import SiteContract.Wire
/-!
# Dependent Edge Contract & Capability Gate (`SiteContract.Api`)

`Request` and `Response` are dependent type families indexed by `Version`.
Client and server handlers match every published version without a wildcard arm,
so adding `Version.v3` fails compilation across every consumer until implemented.
-/
namespace Site.Contract

/-- Dependent request family indexed by wire version. -/
def Request : Version → Type
  | .v1 => Wire.V1.ClientFrame
  | .v2 => Wire.V2.ClientFrame

/-- Dependent response family indexed by wire version. -/
def Response : Version → Type
  | .v1 => Wire.V1.ServerFrame
  | .v2 => Wire.V2.ServerFrame

structure Handler (v : Version) where
  encode : Request v → String
  decode : String → Option (Response v)

/-- Exhaustive per-version client codec table (no wildcard arm). -/
def clientHandler : (v : Version) → Handler v
  | .v1 => { encode := Wire.V1.encodeReq, decode := Wire.V1.decodeResp }
  | .v2 => { encode := Wire.V2.encodeReq, decode := Wire.V2.decodeResp }

/-- Select the highest mutually supported protocol version (`v2` preferred when advertised). -/
def negotiateVersion (ad : Advertisement) : Option Version :=
  if ad.versions.contains .v2 then some .v2
  else if ad.versions.contains .v1 then some .v1
  else none

/-- Exhaustive capability requirement for every `V2` client command. -/
def requiredV2Capability : Wire.V2.ClientFrame → Option Capability
  | .reserve _ _ => none
  | .releaseMilestone _ => none
  | .instantRelease _ _ => some .instantRelease

/-- Capability admission gate: checks both negotiated version and required capability. -/
def permitsV2Command (adOpt : Option Advertisement) (cmd : Wire.V2.ClientFrame) : Bool :=
  match adOpt with
  | none => false
  | some ad =>
    ad.versions.contains .v2 &&
      match requiredV2Capability cmd with
      | none => true
      | some cap => ad.capabilities.contains cap

/-- Gate over raw encoded wire payload (guards direct sends and queued outbox retries alike). -/
def permitsEncodedFrame (adOpt : Option Advertisement) (payload : String) : Bool :=
  match adOpt with
  | none => false
  | some ad =>
    match negotiateVersion ad with
    | some .v2 =>
      match Wire.V2.decodeReq payload with
      | some cmd => permitsV2Command (some ad) cmd
      | none => false
    | some .v1 =>
      (Wire.V1.decodeReq payload).isSome
    | none => false

end Site.Contract
