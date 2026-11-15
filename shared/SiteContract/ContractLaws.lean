import SiteContract.Api
/-!
# Kernel-Checked Edge Contract Laws (`[proof-only, 0 B C]`)

Contains only `theorem` declarations over `Site.Contract`, so `lakeport` verifies
every proof and drops this module to zero bytes of linked C/Wasm.
-/
namespace Site.Contract.Laws
open LakeportEffects Site.Contract Site.Contract.Wire

theorem version_parse_slug (v : Version) : Version.parse v.slug = some v := by
  cases v <;> rfl

theorem capability_parse_slug (c : Capability) : Capability.parse c.slug = some c := by
  cases c <;> rfl

theorem empty_versions_rejected (caps : String) :
    parseAdvertisement ["CAPS", "1", "", caps] = none := by
  rfl

theorem unknown_schema_rejected (v c : String) :
    parseAdvertisement ["CAPS", "2", v, c] = none := by
  rfl

theorem unknown_version_rejected :
    parseAdvertisement ["CAPS", "1", "lpw99", "instant_release"] = none := by
  decide

theorem unknown_capability_rejected :
    parseAdvertisement ["CAPS", "1", "lpw2", "unknown_feature"] = none := by
  decide

theorem full_v2_advertisement_roundtrip :
    parseAdvertisement (encodeAdvertisementFields fullV2ServerAd) = some fullV2ServerAd := by
  decide

theorem legacy_advertisement_roundtrip :
    parseAdvertisement (encodeAdvertisementFields legacyServerAd) = some legacyServerAd := by
  decide

theorem v1_decodeReq_encodeReq (f : V1.ClientFrame) :
    V1.decodeReq (V1.encodeReq f) = some f := by
  cases f with
  | reserve cid cents =>
    simp [V1.encodeReq, V1.decodeReq, WirePack.unpackPair_packPair, parseDecimalNat?_repr]
  | releaseMilestone cid =>
    simp [V1.encodeReq, V1.decodeReq, WirePack.unpackPair_packPair]

theorem v1_decodeResp_encodeResp (f : V1.ServerFrame) :
    V1.decodeResp (V1.encodeResp f) = some f := by
  cases f with
  | ack cid av hd rl =>
    simp [V1.encodeResp, V1.decodeResp, WirePack.unpackPair_packPair, parseDecimalNat?_repr]
  | rejected cid reason =>
    simp [V1.encodeResp, V1.decodeResp, WirePack.unpackPair_packPair]

theorem v2_decodeReq_encodeReq (f : V2.ClientFrame) :
    V2.decodeReq (V2.encodeReq f) = some f := by
  cases f with
  | reserve cid cents =>
    simp [V2.encodeReq, V2.decodeReq, WirePack.unpackPair_packPair, parseDecimalNat?_repr]
  | releaseMilestone cid =>
    simp [V2.encodeReq, V2.decodeReq, WirePack.unpackPair_packPair]
  | instantRelease cid cents =>
    simp [V2.encodeReq, V2.decodeReq, WirePack.unpackPair_packPair, parseDecimalNat?_repr]

theorem v2_decodeResp_encodeResp (f : V2.ServerFrame) :
    V2.decodeResp (V2.encodeResp f) = some f := by
  cases f with
  | ack cid av hd rl receipt =>
    simp [V2.encodeResp, V2.decodeResp, WirePack.unpackPair_packPair, parseDecimalNat?_repr]
  | rejected cid reason =>
    simp [V2.encodeResp, V2.decodeResp, WirePack.unpackPair_packPair]

theorem gate_blocks_unnegotiated_instant (cid : String) (cents : Nat) :
    permitsV2Command (some dualServerBaselineAd) (.instantRelease cid cents) = false := by
  rfl

theorem gate_blocks_legacy_v1_instant (cid : String) (cents : Nat) :
    permitsV2Command (some legacyServerAd) (.instantRelease cid cents) = false := by
  rfl

theorem gate_blocks_missing_negotiation (cmd : V2.ClientFrame) :
    permitsV2Command none cmd = false := by
  rfl

theorem gate_blocks_injected_instant_on_legacy (cid : String) (cents : Nat) :
    permitsEncodedFrame (some legacyServerAd) (V2.encodeReq (.instantRelease cid cents)) = false := by
  simp [permitsEncodedFrame, legacyServerAd, negotiateVersion, V2.encodeReq,
        V1.decodeReq, WirePack.unpackPair_packPair]

/-- Productive witness: once backend advertises `lpw2` + `instant_release`, command admission succeeds. -/
theorem gate_allows_negotiated_instant_productive (cid : String) (cents : Nat) :
    permitsEncodedFrame (some fullV2ServerAd) (V2.encodeReq (.instantRelease cid cents)) = true := by
  simp [permitsEncodedFrame, fullV2ServerAd, negotiateVersion, v2_decodeReq_encodeReq,
        permitsV2Command, requiredV2Capability]

end Site.Contract.Laws
