import Loam.Core.EventMemory
import Std

namespace Loam.ShadowQuantityCli

open Loam.Core

set_option autoImplicit false

/--
One source event while a journal snapshot is being parsed.

The generated EventId / EffectKey values are run-local representation witnesses
only. They are never written anywhere and carry no cross-run continuity claim.
-/
private structure PendingEvent where
  eventIndex : Nat
  effects : List Effect := []
  nextEffectIndex : Nat := 0

/-- Aggregate parse evidence retained for the local report. -/
private structure ParseEvidence where
  sourceEvents : Nat := 0
  sourceEffects : Nat := 0
  headerContexts : Nat := 0
  metadataLines : Nat := 0
  includeDirectives : Nat := 0

private structure ParseState where
  events : List Event := []
  current : Option PendingEvent := none
  nextEventIndex : Nat := 0
  evidence : ParseEvidence := {}
  errorLines : List Nat := []

private def looksLikeDateHeader (text : String) : Bool :=
  match text.toList with
  | a :: b :: c :: d :: '-' :: e :: f :: '-' :: g :: h :: _ =>
      a.isDigit && b.isDigit && c.isDigit && d.isDigit &&
      e.isDigit && f.isDigit && g.isDigit && h.isDigit
  | _ => false

private def runLocalEventId (eventIndex : Nat) : EventId :=
  ⟨"shadow-run-event-" ++ toString eventIndex⟩

private def runLocalEffectKey (eventIndex effectIndex : Nat) : EffectKey :=
  ⟨"shadow-run-effect-" ++ toString eventIndex ++ "-" ++ toString effectIndex⟩

private def finalizeCurrent (state : ParseState) : ParseState :=
  match state.current with
  | none => state
  | some pending =>
      match Event.ofEffects? (runLocalEventId pending.eventIndex) pending.effects with
      | none =>
          { state with
            current := none
            errorLines := 0 :: state.errorLines }
      | some event =>
          { state with
            events := state.events ++ [event]
            current := none
            evidence :=
              { state.evidence with
                sourceEvents := state.evidence.sourceEvents + 1 } }

private def normalizeWhitespace (text : String) : String :=
  text.replace "\t" " "

private def nonemptyTokens (text : String) : List String :=
  (normalizeWhitespace text).splitOn " " |>.filter (fun token => !token.isEmpty)

private def parsePosting
    (eventIndex effectIndex : Nat) (trimmed : String) : Option Effect :=
  match (nonemptyTokens trimmed).reverse with
  | measure :: quantaText :: reversedLocus =>
      let locus := String.intercalate " " reversedLocus.reverse
      if locus.isEmpty then
        none
      else
        match quantaText.toInt? with
        | none => none
        | some quanta =>
            some <|
              Effect.ofQuantity
                (runLocalEffectKey eventIndex effectIndex)
                ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
  | _ => none

private def hasHeaderContext (trimmed : String) : Bool :=
  trimmed.length > 10

private def scanLines
    (lines : List String) (lineNo : Nat := 1) (state : ParseState := {}) : ParseState :=
  match lines with
  | [] => finalizeCurrent state
  | line :: rest =>
      let leftTrimmed := line.trimAsciiStart.toString
      let trimmed := leftTrimmed.trimAsciiEnd.toString
      let indented := leftTrimmed != line
      if trimmed.isEmpty then
        scanLines rest (lineNo + 1) state
      else if !indented && trimmed.startsWith "include " then
        let next :=
          { state with
            evidence :=
              { state.evidence with
                includeDirectives := state.evidence.includeDirectives + 1 } }
        scanLines rest (lineNo + 1) next
      else if !indented && (trimmed.startsWith ";" || trimmed.startsWith "#") then
        let next :=
          { state with
            evidence :=
              { state.evidence with
                metadataLines := state.evidence.metadataLines + 1 } }
        scanLines rest (lineNo + 1) next
      else if !indented && looksLikeDateHeader trimmed then
        let closed := finalizeCurrent state
        let eventIndex := closed.nextEventIndex
        let evidence :=
          if hasHeaderContext trimmed then
            { closed.evidence with
              headerContexts := closed.evidence.headerContexts + 1 }
          else
            closed.evidence
        let next :=
          { closed with
            current := some { eventIndex := eventIndex }
            nextEventIndex := eventIndex + 1
            evidence := evidence }
        scanLines rest (lineNo + 1) next
      else
        match state.current with
        | none =>
            let next := { state with errorLines := lineNo :: state.errorLines }
            scanLines rest (lineNo + 1) next
        | some pending =>
            if indented && trimmed.startsWith ";" then
              let next :=
                { state with
                  evidence :=
                    { state.evidence with
                      metadataLines := state.evidence.metadataLines + 1 } }
              scanLines rest (lineNo + 1) next
            else if indented then
              match parsePosting pending.eventIndex pending.nextEffectIndex trimmed with
              | none =>
                  let next := { state with errorLines := lineNo :: state.errorLines }
                  scanLines rest (lineNo + 1) next
              | some effect =>
                  let updated :=
                    { pending with
                      effects := pending.effects ++ [effect]
                      nextEffectIndex := pending.nextEffectIndex + 1 }
                  let next :=
                    { state with
                      current := some updated
                      evidence :=
                        { state.evidence with
                          sourceEffects := state.evidence.sourceEffects + 1 } }
                  scanLines rest (lineNo + 1) next
            else
              let next := { state with errorLines := lineNo :: state.errorLines }
              scanLines rest (lineNo + 1) next

private def addCoordinateIfAbsent
    (coordinates : List EffectCoordinate)
    (coordinate : EffectCoordinate) : List EffectCoordinate :=
  if coordinate ∈ coordinates then
    coordinates
  else
    coordinates ++ [coordinate]

private def recordedCoordinates (memory : EventMemory) : List EffectCoordinate :=
  memory.events.foldl
    (fun coordinates event =>
      event.effects.foldl
        (fun current effect => addCoordinateIfAbsent current effect.coordinate)
        coordinates)
    []

private def printEvidence (evidence : ParseEvidence) : IO Unit := do
  IO.println "Shadow source coverage:"
  IO.println ("  events projected: " ++ toString evidence.sourceEvents)
  IO.println ("  effects projected: " ++ toString evidence.sourceEffects)
  IO.println ("  header contexts not projected: " ++ toString evidence.headerContexts)
  IO.println ("  metadata lines not projected: " ++ toString evidence.metadataLines)
  IO.println ("  include directives not projected: " ++ toString evidence.includeDirectives)

private def printQuantities (memory : EventMemory) : IO Unit := do
  IO.println "Recorded quantity projection (stateless shadow; run-local identity discarded on exit):"
  let coordinates := recordedCoordinates memory
  match coordinates with
  | [] => IO.println "  (no quantity coordinates)"
  | _ =>
      for coordinate in coordinates do
        let quantity :=
          EventMemory.quantityAtRecorded memory coordinate.locus coordinate.measure
        IO.println
          ("  " ++ coordinate.locus.token ++ ": " ++
            toString quantity.quanta ++ " " ++ coordinate.measure.token)

/--
Parse one journal snapshot without writing the source or any LOAM persistence.

Every EventId and EffectKey created here is unique only within this invocation.
The command is therefore limited to the identity-renaming-invariant recorded
quantity projection established by Observation 078. It must not be reused for
correction, relation, reconciliation, or cross-run identity lookup.
-/
def shadowQuantity (path : String) : IO UInt32 := do
  let source := System.FilePath.mk path
  if !(← source.pathExists) then
    IO.eprintln "loam: shadow quantity source file not found"
    return 2
  let text ← IO.FS.readFile source
  let parsed := scanLines (text.splitOn "\n")
  if !parsed.errorLines.isEmpty then
    IO.eprintln "loam: shadow quantity refused malformed or unsupported source lines"
    IO.eprintln
      ("loam: unsupported line numbers: " ++
        String.intercalate "," (parsed.errorLines.reverse.map toString))
    IO.eprintln "loam: no LOAM persistence was written"
    return 2
  match EventMemory.ofEvents? parsed.events with
  | none =>
      IO.eprintln "loam: run-local Event identity collision"
      return 2
  | some memory =>
      IO.println "LOAM stateless shadow quantity"
      IO.println "source: read-only; persistence: none; sidecar: none"
      printEvidence parsed.evidence
      printQuantities memory
      return 0

end Loam.ShadowQuantityCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [path] => Loam.ShadowQuantityCli.shadowQuantity path
  | _ => do
      IO.eprintln "usage: shadow-quantity <journal-file>"
      return 2
