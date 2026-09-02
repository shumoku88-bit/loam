import Loam.Application.CorrectionFrontier
import Loam.Application.CurrentQuantity

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/--
One small piece of application evidence saying that a quantity-basis correction
root already reflects one Event correction root.

Neither side gains a new identity. The relation names two existing stable roots
so later quantity-basis correction and later Event correction can both extend
without rewriting this evidence.
-/
structure BasisCutEntry where
  basisRoot : QuantityBasisId
  eventRoot : EventId
deriving Repr, DecidableEq

/--
Finite durable evidence about occurrences already folded into starting bases.
List order carries no chronology, priority, or winner meaning.
-/
abbrev BasisCut := List BasisCutEntry

namespace BasisCut

private def eventIsReplacement : List EventCorrection → EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.replacement = id then true else eventIsReplacement rest id

private def basisIsReplacement : List QuantityBasisCorrection → QuantityBasisId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.replacement = id then true else basisIsReplacement rest id

private def entryRootsPresent
    (events : EventMemory)
    (bases : QuantityBasisMemory)
    (entry : BasisCutEntry) : Bool :=
  (EventMemory.findById? events entry.eventRoot).isSome &&
    (QuantityBasisMemory.findById? bases entry.basisRoot).isSome

private def entryNamesRoots
    (eventCorrections : EventCorrectionMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (entry : BasisCutEntry) : Bool :=
  !(eventIsReplacement eventCorrections.corrections entry.eventRoot) &&
    !(basisIsReplacement basisCorrections.corrections entry.basisRoot)

/--
A cut row must refer to remembered correction roots on both sides. Interior or
terminal replacement ids are rejected instead of being treated as accidental
current aliases.
-/
def admissible
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (cut : BasisCut) : Bool :=
  cut.all fun entry =>
    entryRootsPresent events bases entry &&
      entryNamesRoots eventCorrections basisCorrections entry

/-- Event roots already reflected by one quantity-basis correction root. -/
def eventRootsFor (cut : BasisCut) (basisRoot : QuantityBasisId) : List EventId :=
  cut.foldr
    (fun entry roots =>
      if entry.basisRoot = basisRoot then entry.eventRoot :: roots else roots)
    []

private def findEventByTarget? : List EventCorrection → EventId → Option EventCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.target = id then some correction else findEventByTarget? rest id

private def eventTerminalFrom?
    (corrections : List EventCorrection)
    (current : EventId) : Nat → Option EventId
  | 0 => none
  | fuel + 1 =>
      match findEventByTarget? corrections current with
      | none => some current
      | some correction => eventTerminalFrom? corrections correction.replacement fuel

private def eventTerminalForRoot?
    (corrections : EventCorrectionMemory)
    (root : EventId) : Option EventId :=
  eventTerminalFrom? corrections.corrections root (corrections.corrections.length + 1)

private def eventTerminalsForRoots?
    (corrections : EventCorrectionMemory) : List EventId → Option (List EventId)
  | [] => some []
  | root :: rest => do
      let terminal ← eventTerminalForRoot? corrections root
      let later ← eventTerminalsForRoots? corrections rest
      return terminal :: later

private def findBasisByReplacement? :
    List QuantityBasisCorrection → QuantityBasisId → Option QuantityBasisCorrection
  | [], _ => none
  | correction :: rest, id =>
      if correction.replacement = id then
        some correction
      else
        findBasisByReplacement? rest id

private def basisRootFromTerminal?
    (corrections : List QuantityBasisCorrection)
    (current : QuantityBasisId) : Nat → Option QuantityBasisId
  | 0 => none
  | fuel + 1 =>
      match findBasisByReplacement? corrections current with
      | none => some current
      | some correction => basisRootFromTerminal? corrections correction.target fuel

private def basisRootForCurrent?
    (corrections : QuantityBasisCorrectionMemory)
    (current : QuantityBasisId) : Option QuantityBasisId :=
  basisRootFromTerminal?
    corrections.corrections current (corrections.corrections.length + 1)

private def matchingBases
    (bases : List QuantityBasis)
    (locus : LocusId)
    (measure : MeasureId) : List QuantityBasis :=
  bases.filter fun basis => decide (basis.coordinate = ⟨locus, measure⟩)

private def quantityAfterExcluded?
    (frontier : EventMemory)
    (excluded : List EventId)
    (locus : LocusId)
    (measure : MeasureId) : Option Quantity := do
  let retained ← EventMemory.ofEvents? <|
    frontier.events.filter fun event => !(decide (event.id ∈ excluded))
  return EventMemory.quantityAtRecorded retained locus measure

private def addQuantities (left right : Quantity) : Quantity :=
  Quantity.ofQuanta (left.quanta + right.quanta)

/--
Inspect one current quantity while excluding occurrence roots already reflected
by the selected starting basis.

An empty cut exactly delegates to the earlier current-quantity boundary. With a
nonempty cut, both correction families must still justify their ordinary
frontiers. Cut rows are normalized through stable correction roots rather than
through storage order, timestamps, or current replacement ids.

`none` means the supplied basis-cut evidence itself is not admissible. Ordinary
quantity refusals remain represented by `CurrentQuantityAnswer`.
-/
def inspectCurrentQuantityWithBasisCut?
    (events : EventMemory)
    (eventCorrections : EventCorrectionMemory)
    (bases : QuantityBasisMemory)
    (basisCorrections : QuantityBasisCorrectionMemory)
    (cut : BasisCut)
    (locus : LocusId)
    (measure : MeasureId) : Option CurrentQuantityAnswer :=
  if cut.isEmpty then
    some <| inspectCurrentQuantityWithBasisCorrections
      events eventCorrections bases basisCorrections locus measure
  else
    match admittedQuantityBasisFrontier? bases basisCorrections with
    | none => some .basisFrontierRequired
    | some basisFrontier =>
        match matchingBases basisFrontier locus measure with
        | [] => some .basisMissing
        | [basis] =>
            if !admissible events eventCorrections bases basisCorrections cut then
              none
            else
              match basisRootForCurrent? basisCorrections basis.id with
              | none => none
              | some basisRoot =>
                  let roots := eventRootsFor cut basisRoot
                  if roots.isEmpty then
                    some <| inspectCurrentQuantityWithBasisCorrections
                      events eventCorrections bases basisCorrections locus measure
                  else
                    match inspectQuantity events eventCorrections locus measure with
                    | .missingCorrectionEndpoint => some .missingEventCorrectionEndpoint
                    | .frontierRequired => some .eventFrontierRequired
                    | _ =>
                        match correctionFrontierMemory? events eventCorrections with
                        | none => some .eventFrontierRequired
                        | some eventFrontier =>
                            match eventTerminalsForRoots? eventCorrections roots with
                            | none => none
                            | some excluded =>
                                match quantityAfterExcluded?
                                    eventFrontier excluded locus measure with
                                | none => none
                                | some later => some (.current (addQuantities basis.quantity later))
        | _ => some .basisFrontierRequired

end BasisCut

end Loam.Application
