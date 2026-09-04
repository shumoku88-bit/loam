import Loam.Core

namespace Loam.Observation149

set_option autoImplicit false

/-!
# Observation 149 — canonical persistence topology

The current LOAM data generation keeps EventMemory, ActualValidity,
EventDescription, Scheduled, QuantityBasis, and view configuration in distinct
physical files. That layout may be either an earned semantic boundary or merely
historical storage shape.

This observation separates three proposals:

1. current sidecar layout;
2. one unified Actual file for Event + date + description evidence;
3. a semantic `actual/` directory that groups the three Actual streams without
   merging their write units.

A fourth household-monolith specimen is included as a negative boundary.

The question is deliberately physical:

> Which changes preserve the current write partition, and which changes merge
> authority / failure domains and therefore require a new publication model?

No canonical household data is changed here.
-/

inductive Stream
  | events
  | actualValidity
  | descriptions
  | scheduled
  | basis
  | view
  deriving Repr, DecidableEq

inductive Directory
  | root
  | actual
  deriving Repr, DecidableEq

inductive FileSlot
  | events
  | actualValidity
  | descriptions
  | scheduled
  | basis
  | view
  | actualUnified
  | householdUnified
  deriving Repr, DecidableEq

structure Placement where
  directory : Directory
  file : FileSlot
  deriving Repr, DecidableEq

abbrev Topology := Stream → Placement

private def allStreams : List Stream :=
  [ .events,
    .actualValidity,
    .descriptions,
    .scheduled,
    .basis,
    .view ]

private def actualStreams : List Stream :=
  [.events, .actualValidity, .descriptions]

private def nonActualStreams : List Stream :=
  [.scheduled, .basis, .view]

private def current : Topology
  | .events => ⟨.root, .events⟩
  | .actualValidity => ⟨.root, .actualValidity⟩
  | .descriptions => ⟨.root, .descriptions⟩
  | .scheduled => ⟨.root, .scheduled⟩
  | .basis => ⟨.root, .basis⟩
  | .view => ⟨.root, .view⟩

private def semanticDirectory : Topology
  | .events => ⟨.actual, .events⟩
  | .actualValidity => ⟨.actual, .actualValidity⟩
  | .descriptions => ⟨.actual, .descriptions⟩
  | .scheduled => ⟨.root, .scheduled⟩
  | .basis => ⟨.root, .basis⟩
  | .view => ⟨.root, .view⟩

private def unifiedActual : Topology
  | .events => ⟨.root, .actualUnified⟩
  | .actualValidity => ⟨.root, .actualUnified⟩
  | .descriptions => ⟨.root, .actualUnified⟩
  | .scheduled => ⟨.root, .scheduled⟩
  | .basis => ⟨.root, .basis⟩
  | .view => ⟨.root, .view⟩

private def householdMonolith : Topology
  | _ => ⟨.root, .householdUnified⟩

private def sameFile (topology : Topology) (left right : Stream) : Bool :=
  decide ((topology left).file = (topology right).file)

private def samePlacement (left right : Topology) (stream : Stream) : Bool :=
  decide (left stream = right stream)

private def sameWritePartition (left right : Topology) : Bool :=
  allStreams.all fun a =>
    allStreams.all fun b =>
      sameFile left a b == sameFile right a b

private def samePlacementEverywhere (left right : Topology) : Bool :=
  allStreams.all fun stream => samePlacement left right stream

private def eventAuthorityDedicated (topology : Topology) : Bool :=
  !(sameFile topology .events .actualValidity) &&
  !(sameFile topology .events .descriptions)

private def actualSeparatedFromNonActual (topology : Topology) : Bool :=
  actualStreams.all fun actual =>
    nonActualStreams.all fun other =>
      !(sameFile topology actual other)

private def nonActualPairwiseSeparate (topology : Topology) : Bool :=
  !(sameFile topology .scheduled .basis) &&
  !(sameFile topology .scheduled .view) &&
  !(sameFile topology .basis .view)

private def wholeActualOneWriteUnit (topology : Topology) : Bool :=
  sameFile topology .events .actualValidity &&
  sameFile topology .events .descriptions

private def representationOnlyFromCurrent (candidate : Topology) : Bool :=
  sameWritePartition current candidate &&
  !(samePlacementEverywhere current candidate)

/--
Moving the three existing Actual files under one semantic directory changes
paths but not which streams share a physical write unit.
-/
theorem semantic_directory_preserves_write_partition :
    sameWritePartition current semanticDirectory = true := by
  decide

/-- The directory move is therefore a genuine representation-only candidate. -/
theorem semantic_directory_is_representation_only :
    representationOnlyFromCurrent semanticDirectory = true := by
  decide

/--
The existing Event authority file remains physically distinct from occurrence
and description evidence under the semantic-directory candidate.
-/
theorem semantic_directory_preserves_event_authority_isolation :
    eventAuthorityDedicated semanticDirectory = true := by
  decide

/--
Actual remains physically separate from Scheduled, QuantityBasis, and view
configuration under the semantic-directory candidate.
-/
theorem semantic_directory_preserves_family_boundaries :
    actualSeparatedFromNonActual semanticDirectory = true ∧
    nonActualPairwiseSeparate semanticDirectory = true := by
  decide

/--
Putting Event, ActualValidity, and EventDescription in one file changes the
current write partition. It is not merely a path cleanup.
-/
theorem unified_actual_changes_write_partition :
    sameWritePartition current unifiedActual = false := by
  decide

/--
A unified Actual file makes the whole Actual bundle one write unit and removes
the currently dedicated Event authority file boundary.
-/
theorem unified_actual_requires_new_publication_boundary :
    wholeActualOneWriteUnit unifiedActual = true ∧
    eventAuthorityDedicated unifiedActual = false := by
  decide

/--
The unified-Actual proposal can still keep Actual physically separate from
Scheduled, QuantityBasis, and view configuration. Its pressure is specifically
inside the Actual publication protocol, not across all household fact families.
-/
theorem unified_actual_keeps_non_actual_families_independent :
    actualSeparatedFromNonActual unifiedActual = true ∧
    nonActualPairwiseSeparate unifiedActual = true := by
  decide

/--
A whole-household monolith merges independent fact families into one write and
failure domain, so it cannot be classified as representation-only cleanup.
-/
theorem household_monolith_couples_independent_families :
    actualSeparatedFromNonActual householdMonolith = false ∧
    nonActualPairwiseSeparate householdMonolith = false ∧
    sameWritePartition current householdMonolith = false := by
  decide

/--
Among the three concrete alternatives, only the semantic-directory specimen
changes physical placement while preserving the current write partition.
-/
theorem representation_only_boundary :
    representationOnlyFromCurrent semanticDirectory = true ∧
    representationOnlyFromCurrent unifiedActual = false ∧
    representationOnlyFromCurrent householdMonolith = false := by
  decide

end Loam.Observation149
