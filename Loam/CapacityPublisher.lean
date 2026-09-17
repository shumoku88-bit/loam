import Loam.ActualDate
import Loam.Application.CapacityInspection
import Loam.CapacityAuthority
import Loam.FreshNumberedToken
import Loam.Persistence.TokenSyntax
import Loam.WriterOwnership

namespace Loam.CapacityPublisher

open Loam.Core
open Loam.Application

set_option autoImplicit false

/-!
# Shared Capacity publisher

This module owns the surface-independent practical write boundary for one dated
JPY Capacity movement. It deliberately stores no grant / transfer / return kind:
those remain interpretations of the two typed endpoints.

Publication preserves the existing fail-closed ordering used by the practical
CLI: effective-coordinate evidence is published first, then Capacity authority.
If the second publication fails, the effective entry is inert because no
Capacity movement with that identity exists; later writes refuse incomplete
evidence and require explicit recovery rather than guessing the missing movement.

Physical companion placement is owned by `CapacityAuthority`; this publisher
operates only on the two retained semantic families returned by that boundary.
-/

structure Draft where
  effectiveOn : String
  source : CapacityCoordinate
  destination : CapacityCoordinate
  quanta : Int
  deriving Repr, DecidableEq

/--
A multi-coordinate balanced Capacity draft.

All signed changes must sum to exact zero in JPY and every Purpose coordinate's
resulting entitlement must remain non-negative.
-/
structure BalancedDraft where
  effectiveOn : String
  changes : List (MovementChange CapacityCoordinate)
  deriving Repr, DecidableEq

private def hasDuplicateCoordinates (changes : List (MovementChange CapacityCoordinate)) : Bool :=
  let rec check (seen : List CapacityCoordinate) : List (MovementChange CapacityCoordinate) → Bool
    | [] => false
    | c :: rest => if c.coordinate ∈ seen then true else check (c.coordinate :: seen) rest
  check [] changes

private def coordinatePersistable : CapacityCoordinate → Bool
  | .unallocated => true
  | .purpose purpose => Loam.Persistence.validToken purpose.token

/--
Validate one multi-coordinate draft and return the balanced movement evidence
that downstream publication needs. The balance law is checked exactly once at
this boundary and then carried by `BalancedMovement`.
-/
def validateBalancedDraft
    (draft : BalancedDraft) : Except String (BalancedMovement CapacityCoordinate) := do
  if !Loam.ActualDate.validIsoDate draft.effectiveOn then
    throw "Capacity effective date must be a real calendar date in YYYY-MM-DD form."
  if draft.changes.isEmpty then
    throw "Capacity movement changes must not be empty."
  if draft.changes.any (fun c => c.quantity.quanta == 0) then
    throw "Capacity movement changes must have non-zero quantities."
  if hasDuplicateCoordinates draft.changes then
    throw "Capacity movement changes must not contain duplicate coordinates."
  if !draft.changes.all (fun c => coordinatePersistable c.coordinate) then
    throw "Capacity movement coordinate contains an invalid Purpose token."
  let some movement := BalancedMovement.ofChanges? ⟨"jpy"⟩ draft.changes
    | throw "Capacity movement changes must balance to zero."
  return movement

/-- Convert a binary transfer Draft into an equivalent 2-change BalancedDraft. -/
def Draft.toBalancedDraft (draft : Draft) : BalancedDraft :=
  { effectiveOn := draft.effectiveOn
  , changes :=
      [ { coordinate := draft.source, quantity := Quantity.ofQuanta (-draft.quanta) }
      , { coordinate := draft.destination, quantity := Quantity.ofQuanta draft.quanta } ] }

/--
The binary transfer constructor is balanced by construction, independently of
its operation-specific positivity, endpoint, and entitlement admission.
-/
def Draft.toBalancedMovement (draft : Draft) : BalancedMovement CapacityCoordinate :=
  { measure := ⟨"jpy"⟩
    changes := draft.toBalancedDraft.changes
    balanced := by
      simp [Draft.toBalancedDraft, movementTotalQuanta] }

/-- Stable presentation token for one minimal Capacity coordinate. -/
def coordinateToken : CapacityCoordinate → String
  | .unallocated => "unallocated"
  | .purpose purpose => purpose.token

/-- Parse the minimal shared endpoint vocabulary without introducing a Purpose registry. -/
def parseCoordinate? (token : String) : Option CapacityCoordinate :=
  if token = "unallocated" then
    some .unallocated
  else if Loam.Persistence.validToken token then
    some (.purpose ⟨token⟩)
  else
    none

/-- Pure shape checks shared by frontends; current entitlement is checked under ownership. -/
def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.effectiveOn then
    throw "Capacity effective date must be a real calendar date in YYYY-MM-DD form."
  if draft.quanta <= 0 then
    throw "Capacity movement amount must be a positive integer JPY quantity."
  if draft.source = draft.destination then
    throw "Capacity movement endpoints must differ."
  if !coordinatePersistable draft.source || !coordinatePersistable draft.destination then
    throw "Capacity movement coordinate contains an invalid Purpose token."

private def effectiveEvidenceComplete
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : Bool :=
  memory.movements.all
      (fun movement => (effective.findByMovementId? movement.id).isSome) &&
    effective.entries.all
      (fun entry => (memory.findById? entry.movement).isSome)

private def freshCapacityId
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String) : CapacityMovementId :=
  let used :=
    memory.movements.map (fun movement => movement.id.token) ++
      effective.entries.map (fun entry => entry.movement.token)
  ⟨Loam.firstUnusedNumberedToken "capacity-" used 1⟩

/--
Publish one already-admitted balanced movement through the one Capacity physical
sequence. Callers retain operation-specific validation and entitlement admission;
this helper owns only fresh identity, append, and effective-first publication mechanics.
-/
private def publishAdmittedMovement
    (capacityFile : System.FilePath)
    (memory : CapacityMemory)
    (effective : CapacityEffectiveMemory String)
    (effectiveOn : String)
    (balanced : BalancedMovement CapacityCoordinate) : IO (Except String CapacityMovementId) := do
  let movementId := freshCapacityId memory effective
  let movement : CapacityMovement := { id := movementId, movement := balanced }
  let some updated := memory.add? movement
    | return .error "Could not append Capacity movement authority."
  let some updatedEffective := CapacityEffectiveMemory.ofEntries?
      (effective.entries ++ [{ movement := movementId, effectiveOn := effectiveOn }])
    | return .error "Could not append Capacity effective evidence."

  if !(← Loam.CapacityAuthority.saveEffective? capacityFile updatedEffective) then
    return .error "Capacity effective evidence could not be published."
  if !(← Loam.CapacityAuthority.saveMovements? capacityFile updated) then
    return .error
      "Capacity authority was not published; already-published effective evidence is inert and requires explicit recovery."

  return .ok movementId

private def publishUnlocked
    (capacityFile : System.FilePath) (draft : Draft) : IO (Except String CapacityMovementId) := do
  match validateDraft draft with
  | .error message => return .error message
  | .ok _ => pure ()

  let image ←
    match ← Loam.CapacityAuthority.loadOrEmpty capacityFile with
    | .ok image => pure image
    | .error message => return .error message
  let memory := image.movements
  let effective := image.effective

  if !effectiveEvidenceComplete memory effective then
    return .error
      "Capacity authority and effective evidence are incomplete; explicit recovery is required."

  if !canMoveCapacityFrom memory.movements draft.source ⟨"jpy"⟩ draft.quanta then
    return .error "Capacity source has insufficient current entitlement."

  let movementId ←
    match ← publishAdmittedMovement
        capacityFile memory effective draft.effectiveOn draft.toBalancedMovement with
    | .ok id => pure id
    | .error message => return .error message

  return .ok movementId

/--
Publish one dated JPY Capacity movement under Capacity writer ownership.

The shared boundary re-reads both retained streams under the lock, rejects
incomplete evidence, checks named-source entitlement, allocates fresh identity,
and publishes effective evidence before the Capacity authority image.
-/
def publish
    (capacityPath : String) (draft : Draft) : IO (Except String CapacityMovementId) := do
  let capacityFile := System.FilePath.mk capacityPath
  Loam.WriterOwnership.withOwnership capacityFile (publishUnlocked capacityFile draft)

private def publishBalancedUnlocked
    (capacityFile : System.FilePath) (draft : BalancedDraft) : IO (Except String CapacityMovementId) := do
  let balanced ←
    match validateBalancedDraft draft with
    | .error message => return .error message
    | .ok movement => pure movement

  let image ←
    match ← Loam.CapacityAuthority.loadOrEmpty capacityFile with
    | .ok image => pure image
    | .error message => return .error message
  let memory := image.movements
  let effective := image.effective

  if !effectiveEvidenceComplete memory effective then
    return .error
      "Capacity authority and effective evidence are incomplete; explicit recovery is required."

  for change in draft.changes do
    match change.coordinate with
    | .purpose purpose =>
        let current := (entitlementAt memory.movements purpose ⟨"jpy"⟩).quanta
        if current + change.quantity.quanta < 0 then
          return .error s!"Capacity Purpose '{purpose.token}' entitlement would become negative: {current + change.quantity.quanta}."
    | .unallocated => pure ()

  let movementId ←
    match ← publishAdmittedMovement capacityFile memory effective draft.effectiveOn balanced with
    | .ok id => pure id
    | .error message => return .error message

  return .ok movementId

/--
Publish one dated multi-coordinate JPY Capacity movement under Capacity writer ownership.

Atomic publication checks that each Purpose entitlement remains non-negative,
allocates one fresh CapacityMovementId, and publishes effective evidence before
Capacity authority.
-/
def publishBalanced
    (capacityPath : String) (draft : BalancedDraft) : IO (Except String CapacityMovementId) := do
  let capacityFile := System.FilePath.mk capacityPath
  Loam.WriterOwnership.withOwnership capacityFile (publishBalancedUnlocked capacityFile draft)

/--
Finite local proposal for Purpose capacity deltas.

This lives on the client/TUI boundary and maps Purpose identities to signed JPY
deltas. It is never stored as canonical state. Downstream pure projections
evaluate proposal balance, negative entitlement refusal, and coverage
consequences on every edit.
-/
structure Proposal where
  deltas : List (PurposeId × Int) := []
  deriving Repr, DecidableEq

namespace Proposal

/-- An empty proposal with zero deltas. -/
def empty : Proposal := {}

/-- Current delta for one Purpose, defaulting to 0. -/
def delta (p : Proposal) (purpose : PurposeId) : Int :=
  match p.deltas.find? (fun (k, _) => k = purpose) with
  | some (_, d) => d
  | none => 0

/-- Set or update the delta for one Purpose. If delta is 0, the entry is pruned. -/
def set (p : Proposal) (purpose : PurposeId) (newDelta : Int) : Proposal :=
  let filtered := p.deltas.filter (fun (k, _) => k != purpose)
  if newDelta == 0 then
    { deltas := filtered }
  else
    { deltas := filtered ++ [(purpose, newDelta)] }

/-- Reset one Purpose's delta to 0. -/
def clearPurpose (p : Proposal) (purpose : PurposeId) : Proposal :=
  p.set purpose 0

/-- Clear the entire proposal. -/
def clear (_ : Proposal) : Proposal :=
  empty

/-- Exact sum of all deltas in the proposal. -/
def balance (p : Proposal) : Int :=
  p.deltas.foldl (fun sum (_, d) => sum + d) 0

/-- True when all proposed deltas sum to exact zero. -/
def isBalanced (p : Proposal) : Bool :=
  p.balance == 0

/-- True when at least one non-zero delta is present. -/
def hasChanges (p : Proposal) : Bool :=
  p.deltas.any (fun (_, d) => d != 0)

/-- Convert non-zero proposal deltas into Capacity movement changes. -/
def toChanges (p : Proposal) : List (MovementChange CapacityCoordinate) :=
  (p.deltas.filter (fun (_, d) => d != 0)).map fun (purpose, d) =>
    { coordinate := .purpose purpose, quantity := Quantity.ofQuanta d }

/--
Validate and build one publishable `BalancedDraft` from this proposal.
Fails closed if the proposal is empty, unbalanced, or invalid.
-/
def toBalancedDraft (effectiveOn : String) (p : Proposal) : Except String BalancedDraft := do
  if !p.hasChanges then
    throw "Proposal has no non-zero changes."
  if !p.isBalanced then
    throw s!"Proposal is unbalanced ({p.balance} JPY)."
  let draft : BalancedDraft := {
    effectiveOn := effectiveOn
    changes := p.toChanges
  }
  let _ ← validateBalancedDraft draft
  return draft

/-- Find all purposes whose proposed entitlement (current + delta) would be strictly negative. -/
def negativePurposes
    (currentEntitlements : List (PurposeId × Int))
    (p : Proposal) : List (PurposeId × Int) :=
  currentEntitlements.filterMap fun (purpose, current) =>
    let d := p.delta purpose
    let proposed := current + d
    if proposed < 0 then some (purpose, proposed) else none

end Proposal

end Loam.CapacityPublisher
