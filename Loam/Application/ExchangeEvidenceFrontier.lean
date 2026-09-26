import Loam.Application.CorrectionFrontier
import Loam.Core.ExchangeEvidence

namespace Loam.Application

open Loam.Core

set_option autoImplicit false

/-!
# Exchange evidence admission

Production admission strengthens the research candidate from Observation 340
just enough to let one cross-Measure Event bypass ordinary per-Measure balance
without turning EXCHANGE into a generic escape hatch.

A qualified Event must:

- contain both selected keyed Effects;
- use distinct source/destination Measures;
- have negative selected source quantity and positive selected destination quantity;
- contain no third Measure;
- have a negative total in the source Measure and positive total in the
  destination Measure;
- not participate in Event correction while effect-level replacement semantics
  remain unqualified.

Additional Effects in either selected Measure remain allowed, which preserves
fee-bearing exchange occurrences without assigning fee semantics here.
-/

private def findEffectByKey?
    (event : Event)
    (key : EffectKey) : Option Effect :=
  event.effects.find? fun effect => effect.key = some key

private def measureTotal?
    (event : Event)
    (measure : MeasureId) : Option Int := do
  let total ← (Effect.measureTotals event.effects).find? fun item =>
    item.1 = measure
  pure total.2

private def correctionMentions
    (corrections : EventCorrectionMemory)
    (event : EventId) : Bool :=
  corrections.corrections.any fun correction =>
    decide (correction.target = event) ||
      decide (correction.replacement = event)

/-- Whether one raw exchange claim is semantically admitted. -/
def exchangeEvidenceAdmitted?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (evidence : ExchangeEvidence) : Bool :=
  if correctionMentions corrections evidence.event then
    false
  else
    match events.findById? evidence.event with
    | none => false
    | some event =>
        match findEffectByKey? event evidence.source,
              findEffectByKey? event evidence.destination with
        | some source, some destination =>
            if source.measure = destination.measure then
              false
            else if source.quantity.quanta >= 0 then
              false
            else if destination.quantity.quanta <= 0 then
              false
            else if !event.effects.all (fun effect =>
                decide (effect.measure = source.measure) ||
                  decide (effect.measure = destination.measure)) then
              false
            else
              match measureTotal? event source.measure,
                    measureTotal? event destination.measure with
              | some sourceTotal, some destinationTotal =>
                  decide (sourceTotal < 0) && decide (destinationTotal > 0)
              | _, _ => false
        | _, _ => false

/--
Re-admit the whole retained family.

The Core memory supplies deterministic representation and Event uniqueness;
this boundary rechecks that raw rows still resolve to qualified Effects.
-/
def admittedExchangeEvidence?
    (events : EventMemory)
    (corrections : EventCorrectionMemory)
    (memory : ExchangeEvidenceMemory) : Option ExchangeEvidenceMemory := do
  let readmitted ← ExchangeEvidenceMemory.ofEntries? memory.entries
  if readmitted.entries.all (exchangeEvidenceAdmitted? events corrections) then
    some readmitted
  else
    none

end Loam.Application
