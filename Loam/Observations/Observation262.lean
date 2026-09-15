import Loam.Application.CorrectionFrontier
import Loam.Observations.Observation261

namespace Loam.Observation262

open Loam.Core

set_option autoImplicit false

/-!
# Observation 262 — authoritative correction-chain extraction

Observation 261 proved exact arbitrary finite diff composition for a selected
Event sequence. Observation 262 asks whether retained production correction
evidence can safely supply such a sequence without introducing a new chain
authority.

Production `CorrectionFrontier` already rejects missing referenced endpoints,
branching targets, multi-parent replacements, and cycles. This observation adds
only a research read adapter that follows explicit retained `target -> replacement`
edges after that production admission succeeds.
-/

/-- Observation-local successor lookup over retained raw correction facts. -/
def successorId? : List EventCorrection → EventId → Option EventId
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then
        some correction.replacement
      else
        successorId? rest id

/-- Every successor returned by the reader is justified by one retained correction fact. -/
theorem successorId?_some_mem
    (corrections : List EventCorrection)
    (id successor : EventId)
    (h : successorId? corrections id = some successor) :
    ∃ correction ∈ corrections,
      correction.target = id ∧ correction.replacement = successor := by
  induction corrections with
  | nil =>
      simp [successorId?] at h
  | cons correction rest ih =>
      by_cases hTarget : correction.target = id
      · simp [successorId?, hTarget] at h
        exact ⟨correction, by simp, hTarget, h⟩
      · simp [successorId?, hTarget] at h
        obtain ⟨found, hFound, hFoundTarget, hFoundReplacement⟩ := ih h
        exact ⟨found, by simp [hFound], hFoundTarget, hFoundReplacement⟩

/--
Follow explicit retained successors with a finite fuel bound.

A successful result always ends where no further retained successor is found.
Fuel exhaustion fails closed instead of inventing a terminal.
-/
def walkIds? (corrections : List EventCorrection) : Nat → EventId → Option (List EventId)
  | 0, _ => none
  | fuel + 1, current =>
      match successorId? corrections current with
      | none => some [current]
      | some next => do
          let rest ← walkIds? corrections fuel next
          pure (current :: rest)

/--
Derive a finite correction-id chain only after production correction-frontier
admission succeeds and the requested start Event is remembered.

The `length + 1` fuel is observation-local. Under production admission the
retained topology is already constrained to disjoint finite paths; this reader
still fails closed if traversal does not terminate within that finite bound.
-/
def correctionChainIdsFrom?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (start : EventId) : Option (List EventId) :=
  if Loam.Application.correctionFrontierAdmissible events corrections then
    match EventMemory.findById? events start with
    | none => none
    | some _ => walkIds? corrections.corrections (corrections.corrections.length + 1) start
  else
    none

/-- Unsupported production topology is rejected before any chain is exposed. -/
theorem correctionChainIdsFrom?_inadmissible
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (start : EventId)
    (h : Loam.Application.correctionFrontierAdmissible events corrections = false) :
    correctionChainIdsFrom? events corrections start = none := by
  simp [correctionChainIdsFrom?, h]

/-- Materialize a selected retained Event-id path back into remembered Events. -/
def materializeEventIds?
    (events : EventMemory) : List EventId → Option (List Event)
  | [] => some []
  | id :: rest => do
      let event ← EventMemory.findById? events id
      let tail ← materializeEventIds? events rest
      pure (event :: tail)

/-- Production-admitted correction chain materialized as Events for O261. -/
def correctionEventChainFrom?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (start : EventId) : Option (List Event) := do
  let ids ← correctionChainIdsFrom? events corrections start
  materializeEventIds? events ids

/--
Run O261's arbitrary finite step-delta fold over an extracted correction chain.
The value is absent whenever topology admission, start lookup, traversal, or
Event materialization fails.
-/
def chainDeltaQuantaAtFrom?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (start : EventId)
    (coordinate : EffectCoordinate) : Option Int := do
  let chain ← correctionEventChainFrom? events corrections start
  match chain with
  | [] => none
  | first :: rest =>
      some (Loam.Observation261.chainDeltaSum first rest coordinate)

/--
Any successfully extracted nonempty Event chain inherits O261's exact endpoint
law. The reader adds topology selection only; it adds no second diff arithmetic.
-/
theorem chainDeltaQuantaAtFrom?_eq_endpoint_of_extracted
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (start : EventId)
    (coordinate : EffectCoordinate)
    (first : Event)
    (rest : List Event)
    (hExtracted : correctionEventChainFrom? events corrections start = some (first :: rest)) :
    chainDeltaQuantaAtFrom? events corrections start coordinate =
      some (Loam.Observation258.quantityDeltaQuantaAt
        first (Loam.Observation261.chainLast first rest) coordinate) := by
  simp [chainDeltaQuantaAtFrom?, hExtracted,
    Loam.Observation261.chainDeltaSum_eq_endpoint]

/-- Root/terminal identities from the existing production frontier, stripped of Event payload. -/
def productionRootTerminalIds?
    (events : EventMemory)
    (corrections : EventCorrectionMemory) : Option (List (EventId × EventId)) := do
  let rooted ← Loam.Application.correctionRootTerminalEvents? events corrections
  pure (rooted.map fun pair => (pair.1, pair.2.id))

/-- Terminal identity exposed by the observation-local extracted chain. -/
def extractedTerminalId?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (start : EventId) : Option EventId := do
  let ids ← correctionChainIdsFrom? events corrections start
  ids.getLast?

/-! ## Production topology witness -/

private def wallet : LocusId := ⟨"o262-wallet"⟩
private def yen : MeasureId := ⟨"o262-yen"⟩
private def coordinate : EffectCoordinate := ⟨wallet, yen⟩

private def event (token : String) (quanta : Int) : Event :=
  { id := ⟨token⟩
    effects := [Effect.ofAnonymousQuantity wallet yen (Quantity.ofQuanta quanta)]
    keyNodup := by simp [retainedEffectKeys, Effect.ofAnonymousQuantity] }

private def a : Event := event "o262-a" 10
private def b : Event := event "o262-b" 20
private def c : Event := event "o262-c" 15
private def d : Event := event "o262-d" 30

private def events : EventMemory :=
  { events := [a, b, c, d]
    idNodup := by native_decide }

private def correction (target replacement : String) : EventCorrection :=
  { target := ⟨target⟩, replacement := ⟨replacement⟩ }

private def linear : EventCorrectionMemory :=
  { corrections :=
      [ correction "o262-a" "o262-b"
      , correction "o262-b" "o262-c"
      , correction "o262-c" "o262-d" ]
    idNodup := by native_decide }

private def linearPermuted : EventCorrectionMemory :=
  { corrections :=
      [ correction "o262-c" "o262-d"
      , correction "o262-a" "o262-b"
      , correction "o262-b" "o262-c" ]
    idNodup := by native_decide }

private def branching : EventCorrectionMemory :=
  { corrections :=
      [ correction "o262-a" "o262-b"
      , correction "o262-a" "o262-c" ]
    idNodup := by native_decide }

private def merging : EventCorrectionMemory :=
  { corrections :=
      [ correction "o262-a" "o262-c"
      , correction "o262-b" "o262-c" ]
    idNodup := by native_decide }

private def cycling : EventCorrectionMemory :=
  { corrections :=
      [ correction "o262-a" "o262-b"
      , correction "o262-b" "o262-a" ]
    idNodup := by native_decide }

private def missing : EventCorrectionMemory :=
  { corrections := [correction "o262-a" "o262-missing"]
    idNodup := by native_decide }

/-- The retained linear path is accepted by the real production frontier. -/
theorem linear_is_production_admissible :
    Loam.Application.correctionFrontierAdmissible events linear = true := by
  native_decide

/-- Production admission refuses one target with competing replacements. -/
theorem branching_is_rejected :
    Loam.Application.correctionFrontierAdmissible events branching = false := by
  native_decide

/-- Production admission refuses multi-parent replacement merges. -/
theorem merging_is_rejected :
    Loam.Application.correctionFrontierAdmissible events merging = false := by
  native_decide

/-- Production admission refuses replacement cycles. -/
theorem cycling_is_rejected :
    Loam.Application.correctionFrontierAdmissible events cycling = false := by
  native_decide

/-- Production admission refuses corrections whose referenced endpoint is missing. -/
theorem missing_endpoint_is_rejected :
    Loam.Application.correctionFrontierAdmissible events missing = false := by
  native_decide

/-- The production-admitted retained facts derive the expected ordered correction path. -/
theorem linear_chain_ids_are_derived :
    correctionChainIdsFrom? events linear ⟨"o262-a"⟩ =
      some [⟨"o262-a"⟩, ⟨"o262-b"⟩, ⟨"o262-c"⟩, ⟨"o262-d"⟩] := by
  native_decide

/-- Selected correction-memory permutation does not alter the derived path witness. -/
theorem selected_permutation_same_chain :
    correctionChainIdsFrom? events linearPermuted ⟨"o262-a"⟩ =
      correctionChainIdsFrom? events linear ⟨"o262-a"⟩ := by
  native_decide

/-- Production root/terminal projection and the extracted chain agree on A -> D. -/
theorem production_root_terminal_ids :
    productionRootTerminalIds? events linear =
      some [(⟨"o262-a"⟩, ⟨"o262-d"⟩)] := by
  native_decide

/-- The observation-local extracted chain exposes the same terminal D for root A. -/
theorem extracted_terminal_agrees :
    extractedTerminalId? events linear ⟨"o262-a"⟩ = some ⟨"o262-d"⟩ := by
  native_decide

/-- O261 over the production-derived path reconstructs the exact A -> D +20 delta. -/
theorem production_chain_delta :
    chainDeltaQuantaAtFrom? events linear ⟨"o262-a"⟩ coordinate = some 20 := by
  native_decide

/-- The direct endpoint O258 quantity delta is the same +20 quanta. -/
theorem direct_endpoint_delta :
    Loam.Observation258.quantityDeltaQuantaAt a d coordinate = 20 := by
  native_decide

/-- Unsafe production topologies never expose a correction chain through this adapter. -/
theorem unsafe_topologies_fail_closed :
    correctionChainIdsFrom? events branching ⟨"o262-a"⟩ = none ∧
    correctionChainIdsFrom? events merging ⟨"o262-a"⟩ = none ∧
    correctionChainIdsFrom? events cycling ⟨"o262-a"⟩ = none ∧
    correctionChainIdsFrom? events missing ⟨"o262-a"⟩ = none := by
  native_decide

/-!
Observation boundary:

* production `CorrectionFrontier` remains the topology authority;
* the observation-local reader follows only explicit retained correction edges;
* unsupported branching, merging, missing endpoints, and cycles fail closed before
  any chain is exposed;
* a production-admitted linear path can be materialized into the Event sequence
  expected by O261;
* O261 then supplies the exact endpoint quantity diff without another arithmetic
  implementation or persistent chain-diff state;
* the selected permutation witness confirms the intended order-free behavior on
  the qualified specimen, but O262 does not claim a new general permutation theorem;
* nothing here introduces chronology, Effect lineage, global EffectId, or a new
  canonical correction-chain authority.

A future observation may ask whether the read adapter's permutation independence
and completeness can be proved generically from production admission, rather than
only witnessed on selected admitted paths.
-/

end Loam.Observation262
