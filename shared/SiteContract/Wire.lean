import LakeportEffects
import SiteContract.Versions
/-!
# Versioned Wire Codec (`SiteContract.Wire`)

Concrete `V1` (`lpw1`) and `V2` (`lpw2`) wire frames using `LakeportEffects.WirePack`
bijective ASCII escaping (`|`-delimited segments), so round-trip decoding is total and
stack-safe on a 1 MiB Wasm stack.
-/
namespace Site.Contract.Wire
open LakeportEffects

namespace V1

inductive ClientFrame where
  | reserve (clientId : String) (cents : Nat)
  | releaseMilestone (clientId : String)
  deriving DecidableEq, Repr

inductive ServerFrame where
  | ack (clientId : String) (available held released : Nat)
  | rejected (clientId : String) (reason : String)
  deriving DecidableEq, Repr

def encodeReq : ClientFrame → String
  | .reserve cid cents => WirePack.packPair "V1_RESERVE" (WirePack.packPair cid (Nat.repr cents))
  | .releaseMilestone cid => WirePack.packPair "V1_RELEASE" cid

def decodeReq (raw : String) : Option ClientFrame := do
  let (tag, rest) ← WirePack.unpackPair raw
  if tag = "V1_RESERVE" then
    let (cid, centsRaw) ← WirePack.unpackPair rest
    let cents ← parseDecimalNat? centsRaw
    pure (.reserve cid cents)
  else if tag = "V1_RELEASE" then
    pure (.releaseMilestone rest)
  else none

def encodeResp : ServerFrame → String
  | .ack cid av hd rl =>
    WirePack.packPair "V1_ACK"
      (WirePack.packPair cid (WirePack.packPair (Nat.repr av) (WirePack.packPair (Nat.repr hd) (Nat.repr rl))))
  | .rejected cid reason =>
    WirePack.packPair "V1_REJECT" (WirePack.packPair cid reason)

def decodeResp (raw : String) : Option ServerFrame := do
  let (tag, rest) ← WirePack.unpackPair raw
  if tag = "V1_ACK" then
    let (cid, r1) ← WirePack.unpackPair rest
    let (avRaw, r2) ← WirePack.unpackPair r1
    let (hdRaw, rlRaw) ← WirePack.unpackPair r2
    let av ← parseDecimalNat? avRaw
    let hd ← parseDecimalNat? hdRaw
    let rl ← parseDecimalNat? rlRaw
    pure (.ack cid av hd rl)
  else if tag = "V1_REJECT" then
    let (cid, reason) ← WirePack.unpackPair rest
    pure (.rejected cid reason)
  else none

end V1

namespace V2

inductive ClientFrame where
  | reserve (clientId : String) (cents : Nat)
  | releaseMilestone (clientId : String)
  | instantRelease (clientId : String) (cents : Nat)
  deriving DecidableEq, Repr

inductive ServerFrame where
  | ack (clientId : String) (available held released : Nat) (receiptHash : String)
  | rejected (clientId : String) (reason : String)
  deriving DecidableEq, Repr

def encodeReq : ClientFrame → String
  | .reserve cid cents => WirePack.packPair "V2_RESERVE" (WirePack.packPair cid (Nat.repr cents))
  | .releaseMilestone cid => WirePack.packPair "V2_RELEASE" cid
  | .instantRelease cid cents => WirePack.packPair "V2_INSTANT" (WirePack.packPair cid (Nat.repr cents))

def decodeReq (raw : String) : Option ClientFrame := do
  let (tag, rest) ← WirePack.unpackPair raw
  if tag = "V2_RESERVE" then
    let (cid, centsRaw) ← WirePack.unpackPair rest
    let cents ← parseDecimalNat? centsRaw
    pure (.reserve cid cents)
  else if tag = "V2_RELEASE" then
    pure (.releaseMilestone rest)
  else if tag = "V2_INSTANT" then
    let (cid, centsRaw) ← WirePack.unpackPair rest
    let cents ← parseDecimalNat? centsRaw
    pure (.instantRelease cid cents)
  else none

def encodeResp : ServerFrame → String
  | .ack cid av hd rl receipt =>
    WirePack.packPair "V2_ACK"
      (WirePack.packPair cid
        (WirePack.packPair (Nat.repr av)
          (WirePack.packPair (Nat.repr hd)
            (WirePack.packPair (Nat.repr rl) receipt))))
  | .rejected cid reason =>
    WirePack.packPair "V2_REJECT" (WirePack.packPair cid reason)

def decodeResp (raw : String) : Option ServerFrame := do
  let (tag, rest) ← WirePack.unpackPair raw
  if tag = "V2_ACK" then
    let (cid, r1) ← WirePack.unpackPair rest
    let (avRaw, r2) ← WirePack.unpackPair r1
    let (hdRaw, r3) ← WirePack.unpackPair r2
    let (rlRaw, receipt) ← WirePack.unpackPair r3
    let av ← parseDecimalNat? avRaw
    let hd ← parseDecimalNat? hdRaw
    let rl ← parseDecimalNat? rlRaw
    pure (.ack cid av hd rl receipt)
  else if tag = "V2_REJECT" then
    let (cid, reason) ← WirePack.unpackPair rest
    pure (.rejected cid reason)
  else none

end V2

end Site.Contract.Wire
