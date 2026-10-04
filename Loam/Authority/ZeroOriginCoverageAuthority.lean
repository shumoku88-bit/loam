import Loam.Core.ZeroOriginCoverage
import Loam.Persistence.ZeroOriginCoveragePersistence
import Loam.Authority.HouseholdAuthority

namespace Loam.ZeroOriginCoverageAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Zero-origin coverage authority adapter

ZeroOriginCoverage is exceptional reconstruction/cutover evidence. It has no
ordinary household writer, so this boundary only preserves its existing read
contracts across physical storage topologies.

Two absence meanings already exist in production and must stay distinct:

- optional readers interpret missing ZeroOriginCoverage as semantic empty
  coverage;
- publication guards that require the authority treat missing as unavailable.

Production household reads select the canonical `ZeroOrigin` section.
Explicit standalone paths remain only for low-level legacy diagnostics,
migration, and storage-topology qualification. There is no production fallback
from HouseholdImage to the frozen legacy file.
-/

private def decodeBody?
    (body : String) : Except String ZeroOriginCoverage :=
  match decodeZeroOriginCoverage? body with
  | some coverage => .ok coverage
  | none =>
      .error "loam: malformed or unsupported HouseholdImage zero-origin coverage authority"

/-- Load optional legacy ZeroOriginCoverage. Missing storage means empty coverage. -/
def loadLegacyOrEmpty?
    (path : System.FilePath) : IO (Except String ZeroOriginCoverage) := do
  if !(← path.pathExists) then
    return .ok ZeroOriginCoverage.empty
  match ← loadZeroOriginCoverage? path with
  | some coverage => return .ok coverage
  | none => return .error "loam: malformed or unsupported zero-origin coverage file"

/-- Load required legacy ZeroOriginCoverage. Missing storage remains unavailable. -/
def loadLegacyRequired?
    (path : System.FilePath) : IO (Except String ZeroOriginCoverage) := do
  if !(← path.pathExists) then
    return .error "loam: zero-origin coverage authority is missing"
  match ← loadZeroOriginCoverage? path with
  | some coverage => return .ok coverage
  | none =>
      return .error "loam: zero-origin coverage authority is malformed or unsupported"

/--
Load optional ZeroOriginCoverage from the HouseholdImage `ZeroOrigin` section.

An absent section preserves the established optional-reader meaning of semantic
empty coverage. Malformed present evidence fails closed.
-/
def loadHouseholdOrEmpty?
    (root : System.FilePath) : IO (Except String ZeroOriginCoverage) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  match body? generation.image "ZeroOrigin" with
  | none => return .ok ZeroOriginCoverage.empty
  | some body => return decodeBody? body

/--
Load required ZeroOriginCoverage from the HouseholdImage `ZeroOrigin` section.

An absent section remains unavailable for callers whose guard requires explicit
retained coverage authority.
-/
def loadHouseholdRequired?
    (root : System.FilePath) : IO (Except String ZeroOriginCoverage) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some body := body? generation.image "ZeroOrigin"
    | return .error "loam: required HouseholdImage zero-origin coverage section is missing"
  return decodeBody? body

end Loam.ZeroOriginCoverageAuthority
