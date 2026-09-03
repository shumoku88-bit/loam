import Loam.Core.Event
import Std

namespace Loam.ShadowDayCli

open Loam.Core

set_option autoImplicit false

/--
One source occurrence while a journal-shaped snapshot is being parsed.

`day` and `context` are adapter evidence only. They do not extend `Event` and do
not establish a general LOAM time or description ontology.
-/
private structure PendingOccurrence where
  eventIndex : Nat
  day : String
  context : String
  effects : List Effect := []
  nextEffectIndex : Nat := 0

private structure SourceOccurrence where
  day : String
  context : String
  event : Event

private structure ParseState where
  occurrences : List SourceOccurrence := []
  current : Option PendingOccurrence := none
  nextEventIndex : Nat := 0
  includeDirectives : Nat := 0
  metadataLines : Nat := 0
  errorLines : List Nat := []

private def isDayToken (text : String) : Bool :=
  match text.toList with
  | [a, b, c, d, '-', e, f, '-', g, h] =>
      a.isDigit && b.isDigit && c.isDigit && d.isDigit &&
      e.isDigit && f.isDigit && g.isDigit && h.isDigit
  | _ => false

private def normalizeWhitespace (text : String) : String :=
  text.replace "\t" " "

private def nonemptyTokens (text : String) : List String :=
  (normalizeWhitespace text).splitOn " " |>.filter (fun token => !token.isEmpty)

private def headerParts? (trimmed : String) : Option (String × String) :=
  match nonemptyTokens trimmed with
  | [] => none
  | day :: rest =>
      if isDayToken day then
        some (day, String.intercalate " " rest)
      else
        none

private def runLocalEventId (eventIndex : Nat) : EventId :=
  ⟨"shadow-day-event-" ++ toString eventIndex⟩

private def runLocalEffectKey (eventIndex effectIndex : Nat) : EffectKey :=
  ⟨"shadow-day-effect-" ++ toString eventIndex ++ "-" ++ toString effectIndex⟩

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
            occurrences :=
              state.occurrences ++
                [{ day := pending.day, context := pending.context, event := event }]
            current := none }

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
        let closed := finalizeCurrent state
        let next := { closed with includeDirectives := closed.includeDirectives + 1 }
        scanLines rest (lineNo + 1) next
      else if !indented && (trimmed.startsWith ";" || trimmed.startsWith "#") then
        let next := { state with metadataLines := state.metadataLines + 1 }
        scanLines rest (lineNo + 1) next
      else if !indented then
        match headerParts? trimmed with
        | some (day, context) =>
            let closed := finalizeCurrent state
            let eventIndex := closed.nextEventIndex
            let next :=
              { closed with
                current :=
                  some
                    { eventIndex := eventIndex
                      day := day
                      context := context }
                nextEventIndex := eventIndex + 1 }
            scanLines rest (lineNo + 1) next
        | none =>
            let next := { state with errorLines := lineNo :: state.errorLines }
            scanLines rest (lineNo + 1) next
      else
        match state.current with
        | none =>
            let next := { state with errorLines := lineNo :: state.errorLines }
            scanLines rest (lineNo + 1) next
        | some pending =>
            if trimmed.startsWith ";" then
              let next := { state with metadataLines := state.metadataLines + 1 }
              scanLines rest (lineNo + 1) next
            else
              match parsePosting pending.eventIndex pending.nextEffectIndex trimmed with
              | none =>
                  let next := { state with errorLines := lineNo :: state.errorLines }
                  scanLines rest (lineNo + 1) next
              | some effect =>
                  let updated :=
                    { pending with
                      effects := pending.effects ++ [effect]
                      nextEffectIndex := pending.nextEffectIndex + 1 }
                  scanLines rest (lineNo + 1) { state with current := some updated }

private def printOccurrence (occurrence : SourceOccurrence) : IO Unit := do
  if occurrence.context.isEmpty then
    IO.println "- (recorded occurrence)"
  else
    IO.println ("- " ++ occurrence.context)
  for effect in occurrence.event.effects do
    IO.println
      ("    " ++ effect.locus.token ++ ": " ++
        toString effect.quantity.quanta ++ " " ++ effect.measure.token)

/--
Read one exact day from one journal-shaped source file without persistence.

This is intentionally a file-local, recorded-occurrence query:
- source `include` directives are reported but not followed;
- source context is shown only as human presentation text;
- generated Event / Effect identities are run-local and never printed;
- correction, reversal, AccountType, Plan, Envelope, and Issue semantics are not
  inferred from the source shape.
-/
def shadowDay (day path : String) : IO UInt32 := do
  if !isDayToken day then
    IO.eprintln "loam: shadow day must be YYYY-MM-DD"
    return 2

  let source := System.FilePath.mk path
  if !(← source.pathExists) then
    IO.eprintln "loam: shadow day source file not found"
    return 2

  let text ← IO.FS.readFile source
  let parsed := scanLines (text.splitOn "\n")
  if !parsed.errorLines.isEmpty then
    IO.eprintln "loam: shadow day refused malformed or unsupported source lines"
    IO.eprintln
      ("loam: unsupported line numbers: " ++
        String.intercalate "," (parsed.errorLines.reverse.map toString))
    IO.eprintln "loam: no LOAM persistence was written"
    return 2

  let selected :=
    parsed.occurrences.filter fun occurrence => decide (occurrence.day = day)

  IO.println ("LOAM recorded day " ++ day)
  IO.println "source: read-only; persistence: none; imported source ontology: none"
  if parsed.includeDirectives != 0 then
    IO.println
      ("note: " ++ toString parsed.includeDirectives ++
        " include directive(s) were not followed by this file-local reader")

  if selected.isEmpty then
    IO.println "  (no recorded occurrences)"
  else
    for occurrence in selected do
      printOccurrence occurrence

  return 0

end Loam.ShadowDayCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [day, path] => Loam.ShadowDayCli.shadowDay day path
  | _ => do
      IO.eprintln "usage: loamShadowDay <YYYY-MM-DD> <journal-file>"
      return 2
