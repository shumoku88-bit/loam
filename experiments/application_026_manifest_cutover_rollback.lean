import Std

namespace Loam.Application026

set_option autoImplicit false

/-- Physical authority choice during a one-time sidecar -> manifest cutover. -/
inductive Authority where
  | sidecar
  | manifest
  deriving Repr, BEq, DecidableEq

/-- A selected manifest may be readable or physically broken. -/
inductive ManifestHealth where
  | healthy
  | broken
  deriving Repr, BEq, DecidableEq

/--
`sidecarGeneration` and `manifestGeneration` stand for exact verified generation
fingerprints. Equality means the two physical representations name the same
canonical household world for this bounded migration model.
-/
structure State where
  authority : Authority
  sidecarGeneration : Nat
  manifestGeneration : Nat
  manifestHealth : ManifestHealth
  deriving Repr, BEq, DecidableEq

/--
Read only through the explicitly selected authority.

A broken selected manifest returns unavailable. It never falls back to the
preserved legacy sidecars merely because those bytes still exist.
-/
def readGeneration? (state : State) : Option Nat :=
  match state.authority with
  | .sidecar => some state.sidecarGeneration
  | .manifest =>
      match state.manifestHealth with
      | .healthy => some state.manifestGeneration
      | .broken => none

/--
Cut over only from sidecar authority, only after the prepared manifest is healthy,
and only while both physical representations have the same verified generation.
-/
def cutover? (state : State) : Option State :=
  if state.authority = .sidecar ∧
      state.manifestHealth = .healthy ∧
      state.sidecarGeneration = state.manifestGeneration then
    some { state with authority := .manifest }
  else
    none

/--
The cheap rollback is only an authority-selector reversal. It is admitted only
while the preserved sidecars still fingerprint the selected manifest generation.
-/
def rollback? (state : State) : Option State :=
  if state.authority = .manifest ∧
      state.manifestHealth = .healthy ∧
      state.sidecarGeneration = state.manifestGeneration then
    some { state with authority := .sidecar }
  else
    none

/-- One manifest-native write advances only manifest authority in this model. -/
def manifestWrite? (state : State) : Option State :=
  if state.authority = .manifest ∧ state.manifestHealth = .healthy then
    some { state with manifestGeneration := state.manifestGeneration + 1 }
  else
    none

/-- The unsafe operation this observation explicitly rejects. -/
def naiveRollback (state : State) : State :=
  { state with authority := .sidecar }

/-- Initial equivalent representations can cut over without changing the read answer. -/
theorem cutover_preserves_generation (generation : Nat) :
    let before : State := {
      authority := .sidecar
      sidecarGeneration := generation
      manifestGeneration := generation
      manifestHealth := .healthy
    }
    let after : State := {
      authority := .manifest
      sidecarGeneration := generation
      manifestGeneration := generation
      manifestHealth := .healthy
    }
    cutover? before = some after ∧
      readGeneration? before = readGeneration? after := by
  simp [cutover?, readGeneration?]

/-- Selector rollback is safe before either representation diverges. -/
theorem pre_divergence_rollback_preserves_generation (generation : Nat) :
    let selected : State := {
      authority := .manifest
      sidecarGeneration := generation
      manifestGeneration := generation
      manifestHealth := .healthy
    }
    let rolled : State := {
      authority := .sidecar
      sidecarGeneration := generation
      manifestGeneration := generation
      manifestHealth := .healthy
    }
    rollback? selected = some rolled ∧
      readGeneration? selected = readGeneration? rolled := by
  simp [rollback?, readGeneration?]

/--
After the first manifest-only write, preserved legacy sidecars are no longer an
admissible selector-only rollback target.
-/
theorem manifest_write_closes_preserved_sidecar_rollback (generation : Nat) :
    let selected : State := {
      authority := .manifest
      sidecarGeneration := generation
      manifestGeneration := generation
      manifestHealth := .healthy
    }
    match manifestWrite? selected with
    | none => False
    | some advanced => rollback? advanced = none := by
  simp [manifestWrite?, rollback?]

/-- Blindly selecting the frozen sidecars after divergence changes the generation read. -/
theorem naive_post_divergence_rollback_changes_answer (generation : Nat) :
    let advanced : State := {
      authority := .manifest
      sidecarGeneration := generation
      manifestGeneration := generation + 1
      manifestHealth := .healthy
    }
    readGeneration? (naiveRollback advanced) ≠ readGeneration? advanced := by
  simp [naiveRollback, readGeneration?]

/-- Broken manifest authority is unavailable, not an implicit request for legacy fallback. -/
theorem broken_manifest_never_falls_back
    (sidecarGeneration manifestGeneration : Nat) :
    readGeneration? {
      authority := .manifest
      sidecarGeneration := sidecarGeneration
      manifestGeneration := manifestGeneration
      manifestHealth := .broken
    } = none := by
  rfl

end Loam.Application026

def main : IO Unit := do
  IO.println "Application 026 manifest cutover/rollback model PASS"
  IO.println "explicit_authority_selector=1"
  IO.println "pre_divergence_selector_rollback=1"
  IO.println "post_divergence_selector_rollback=0"
  IO.println "broken_manifest_legacy_fallback=0"
