namespace Loam.Observations.Observation241

set_option autoImplicit false

/-!
Observation 241

Question: when one current operation distinguishes an unavailable authority from
an explicitly available empty authority, is that distinction itself a property
of a particular physical file?

This observation deliberately models only the semantic factorization needed
before a later physical-topology audit. It does not claim that any current file
can already be merged or removed safely.
-/

/-- Availability belongs to the decoded authority state, not to a filename. -/
inductive AuthorityState (α : Type) where
  | unavailable
  | available (value : α)
deriving Repr, DecidableEq

/-- Small observable result corresponding to the current Correction pressure. -/
inductive CorrectionAdmission where
  | admitted
  | refused
  deriving Repr, DecidableEq

/--
A Correction-like operation may proceed only when Reversal authority is
available. The particular retained relation value is deliberately opaque here;
this observation asks only about available versus unavailable authority.
-/
def correctionAdmission {α : Type} : AuthorityState α → CorrectionAdmission
  | .unavailable => .refused
  | .available _ => .admitted

/-- Representative complete empty Reversal authority. -/
def explicitEmptyReversals : AuthorityState (List Unit) :=
  .available []

/-- Representative unavailable Reversal authority. -/
def unavailableReversals : AuthorityState (List Unit) :=
  .unavailable

/--
Known-empty and unavailable authority are observably different for the selected
operation. Therefore an erasure that identifies them is not Q-sufficient.
-/
theorem explicit_empty_is_not_unavailable :
    correctionAdmission explicitEmptyReversals ≠
      correctionAdmission unavailableReversals := by
  decide

/-- Two example physical layouts capable of carrying the same semantic state. -/
inductive PhysicalTopology where
  | separateFile
  | bundledSection
  deriving Repr, DecidableEq

/--
A decoded representation exposes semantic authority state separately from the
container topology that carried it.
-/
structure Representation (α : Type) where
  topology : PhysicalTopology
  authority : AuthorityState α
  deriving Repr, DecidableEq

/-- Observation factors through decoded authority state, not physical topology. -/
def observeRepresentation {α : Type} (representation : Representation α) :
    CorrectionAdmission :=
  correctionAdmission representation.authority

/--
Changing only the physical topology cannot change this selected observable when
the decoded authority state is preserved.
-/
theorem topology_invariant_when_authority_is_preserved
    {α : Type}
    (first second : PhysicalTopology)
    (authority : AuthorityState α) :
    observeRepresentation { topology := first, authority := authority } =
      observeRepresentation { topology := second, authority := authority } := by
  rfl

/--
The representative known-empty state can therefore survive either example
container shape without changing the selected operation result.
-/
theorem explicit_empty_survives_container_change :
    observeRepresentation
        { topology := .separateFile, authority := explicitEmptyReversals } =
      observeRepresentation
        { topology := .bundledSection, authority := explicitEmptyReversals } := by
  rfl

/--
Likewise, unavailable remains unavailable across container shapes. A topology
redesign must preserve this state instead of manufacturing known-empty evidence.
-/
theorem unavailable_survives_container_change :
    observeRepresentation
        { topology := .separateFile, authority := unavailableReversals } =
      observeRepresentation
        { topology := .bundledSection, authority := unavailableReversals } := by
  rfl

end Loam.Observations.Observation241
