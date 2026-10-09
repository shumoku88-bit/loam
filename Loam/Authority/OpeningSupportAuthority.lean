import Loam.Core.OpeningSupport
import Loam.Persistence.OpeningSupportPersistence
import Loam.Authority.HouseholdAuthority

namespace Loam.OpeningSupportAuthority

open Loam.Core
open Loam.Persistence
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Opening support authority adapter

OpeningSupport has no ordinary production writer. Production readers select the
canonical HouseholdImage `OpeningSupport` section while explicit standalone
paths remain available for migration and diagnostics.

Two existing absence contracts remain distinct:

- optional current/historical readers interpret missing OpeningSupport as empty;
- current-anchor publication requires explicit OpeningSupport authority and
  treats missing as unavailable.
-/

private def decodeBody?
    (body : String) : Except String OpeningSupportMap :=
  match decodeOpeningSupportMap? body with
  | some support => .ok support
  | none =>
      .error "loam: malformed or unsupported HouseholdImage opening support authority"

/-- Load optional standalone OpeningSupport. Missing storage means empty support. -/
def loadLegacyOrEmpty?
    (path : System.FilePath) : IO (Except String OpeningSupportMap) := do
  if !(← path.pathExists) then
    return .ok OpeningSupportMap.empty
  match ← loadOpeningSupportMap? path with
  | some support => return .ok support
  | none => return .error "loam: malformed or unsupported opening support evidence"

/-- Load required standalone OpeningSupport. Missing storage remains unavailable. -/
def loadLegacyRequired?
    (path : System.FilePath) : IO (Except String OpeningSupportMap) := do
  if !(← path.pathExists) then
    return .error "loam: opening-support authority is missing"
  match ← loadOpeningSupportMap? path with
  | some support => return .ok support
  | none => return .error "loam: opening-support authority is malformed or unsupported"

/-- Decode optional support from an already-qualified generation without reopening it. -/
def decodeGenerationOrEmpty?
    (generation : Loam.HouseholdAuthority.Generation) : Except String OpeningSupportMap :=
  match body? generation.image "OpeningSupport" with
  | none => .ok OpeningSupportMap.empty
  | some body => decodeBody? body

/--
Load optional OpeningSupport from the HouseholdImage `OpeningSupport` section.

An absent section preserves the established optional-reader meaning of semantic
empty support. A malformed present section fails closed.
-/
def loadHouseholdOrEmpty?
    (root : System.FilePath) : IO (Except String OpeningSupportMap) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  return decodeGenerationOrEmpty? generation

/--
Load required OpeningSupport from the HouseholdImage `OpeningSupport` section.

An absent section remains unavailable for callers whose publication guard
requires explicit retained support authority.
-/
def loadHouseholdRequired?
    (root : System.FilePath) : IO (Except String OpeningSupportMap) := do
  let generation ←
    match ← Loam.HouseholdAuthority.loadCurrent? root with
    | .ok generation => pure generation
    | .error message => return .error message
  let some body := body? generation.image "OpeningSupport"
    | return .error "loam: required HouseholdImage opening support section is missing"
  return decodeBody? body

end Loam.OpeningSupportAuthority
