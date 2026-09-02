import Loam.Core.RelationAdmission
import Loam.Persistence
import Loam.MovementCli
import Std

namespace Loam.CorrectionCli

set_option autoImplicit false

private def promptLine (prompt : String) : IO String := do
  IO.print prompt
  let stdout ← IO.getStdout
  stdout.flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

private def targetsEvent : List Loam.Core.EventCorrection → Loam.Core.EventId → Bool
  | [], _ => false
  | correction :: rest, id =>
      if correction.target = id then
        true
      else
        targetsEvent rest id

private def equalOppositeJpyPair : List Loam.Core.Effect → Bool
  | [left, right] =>
      left.measure.token == "jpy" &&
      right.measure.token == "jpy" &&
      left.quantity.quanta != 0 &&
      right.quantity.quanta != 0 &&
      left.quantity.quanta + right.quantity.quanta == 0
  | _ => false

/--
Candidate shape for the historical human-directed spending correction entrance.

Historical one-Effect records remain selectable. New ordinary spending records
are two-Effect equal-and-opposite JPY pairs. A transfer has the same neutral
physical pair shape, so inclusion here does not classify an Event as spending;
the human explicitly chooses the record they intend to correct.
-/
private def correctableEvents
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory) : List Loam.Core.Event :=
  events.events.filter fun event =>
    (event.effects.length == 1 || equalOppositeJpyPair event.effects) &&
      !(targetsEvent corrections.corrections event.id)

private def summarizeMovementEffects :
    List Loam.Core.Effect → Option (Int × Bool × Bool)
  | [] => some (0, false, false)
  | effect :: rest =>
      if effect.measure.token != "jpy" || effect.quantity.quanta == 0 then
        none
      else
        match summarizeMovementEffects rest with
        | none => none
        | some (total, hasNegative, hasPositive) =>
            let quantity := effect.quantity.quanta
            some
              ( total + quantity,
                hasNegative || quantity < 0,
                hasPositive || quantity > 0 )

/--
Recognize only the shape admitted by the practical balanced-movement entrance:
nonzero JPY Effects, at least one negative and one positive contribution, and a
zero signed total. This is an application candidate predicate, not a Core Event
law and not an accounting classification.
-/
private def balancedJpyMovement (effects : List Loam.Core.Effect) : Bool :=
  match summarizeMovementEffects effects with
  | none => false
  | some (total, hasNegative, hasPositive) =>
      total == 0 && hasNegative && hasPositive

private def correctableMovements
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory) : List Loam.Core.Event :=
  events.events.filter fun event =>
    balancedJpyMovement event.effects &&
      !(targetsEvent corrections.corrections event.id)

private def printCandidates : Nat → List Loam.Core.Event → IO Unit
  | _, [] => pure ()
  | index, event :: rest => do
      IO.println (toString index ++ ". [" ++ event.id.token ++ "]")
      for effect in event.effects do
        IO.println
          ("    " ++ effect.locus.token ++ ": " ++
            toString effect.quantity.quanta ++ " " ++ effect.measure.token)
      printCandidates (index + 1) rest

private def getAt? {α : Type} : List α → Nat → Option α
  | [], _ => none
  | item :: _, 0 => some item
  | _ :: rest, index + 1 => getAt? rest index

private def freshReplacementEventIdFrom
    (memory : Loam.Core.EventMemory) : Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"replacement-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshReplacementEventIdFrom memory (index + 1) fuel

private def freshReplacementEventId?
    (memory : Loam.Core.EventMemory) : Option Loam.Core.EventId :=
  freshReplacementEventIdFrom memory 1 (memory.events.length + 1)

private def freshCorrectionIdFrom
    (memory : Loam.Core.EventCorrectionMemory) : Nat → Nat → Option Loam.Core.EventCorrectionId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventCorrectionId := ⟨"correction-" ++ toString index⟩
      match Loam.Core.EventCorrectionMemory.findById? memory candidate with
      | none => some candidate
      | some _ => freshCorrectionIdFrom memory (index + 1) fuel

private def freshCorrectionId?
    (memory : Loam.Core.EventCorrectionMemory) : Option Loam.Core.EventCorrectionId :=
  freshCorrectionIdFrom memory 1 (memory.corrections.length + 1)

private def loadCorrectionMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return Loam.Core.EventCorrectionMemory.ofCorrections? []

private def spendEntry?
    (useOrAmount amountText : String) : Option (Option String × Int) :=
  match amountText.toInt? with
  | some amount => some (some useOrAmount, amount)
  | none =>
      if amountText.isEmpty then
        match useOrAmount.toInt? with
        | some amount => some (none, amount)
        | none => none
      else
        none

/--
Human-facing entrance for correcting one user-selected spend-shaped recorded
Event without rewriting the original Event.

The selected original remains in EventMemory. The corrected interpretation is a
new Event, connected by one explicit EventCorrection in a separate raw relation
stream. The relation stream is published first; until its replacement Event is
also present, referential admission keeps the dangling relation semantically
inactive. No arrival-order or last-write-wins rule is introduced.

Ordinary interactive correction now records `payment source -q` and `use locus
+q`. Historical two-line scripted input ending after source and amount remains a
one-Effect compatibility path. Structural candidate shape alone does not prove
that a two-Effect Event was spending rather than transfer; the human selection
at this entrance supplies that intent.
-/
def correctSpend (memoryPath correctionPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  if !(← memoryFile.pathExists) then
    IO.eprintln "loam: nothing recorded yet"
    return 2
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some events =>
        match ← loadCorrectionMemoryForEntry? correctionFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported correction-memory file"
            return 2
        | some corrections =>
            let candidates := correctableEvents events corrections
            match candidates with
            | [] =>
                IO.println "No compatible records are available to correct."
                return 0
            | _ =>
                IO.println "Which record should be corrected?"
                printCandidates 1 candidates
                let selectionText ← promptLine "Select number: "
                match selectionText.toNat? with
                | none =>
                    IO.eprintln "loam: choose one of the displayed numbers"
                    return 2
                | some 0 =>
                    IO.eprintln "loam: choose one of the displayed numbers"
                    return 2
                | some selection =>
                    match getAt? candidates (selection - 1) with
                    | none =>
                        IO.eprintln "loam: choose one of the displayed numbers"
                        return 2
                    | some target =>
                        let sourceToken ← promptLine "Paid from? "
                        if Loam.Persistence.validToken sourceToken then
                          let useOrAmount ← promptLine "Used for? "
                          let amountText ← promptLine "Amount? "
                          match spendEntry? useOrAmount amountText with
                          | none =>
                              IO.eprintln "loam: amount must be a positive integer"
                              return 2
                          | some (useToken?, amount) =>
                              if amount > 0 then
                                let useTokenValid :=
                                  match useToken? with
                                  | none => true
                                  | some useToken => Loam.Persistence.validToken useToken
                                let useTokenDiffers :=
                                  match useToken? with
                                  | none => true
                                  | some useToken => sourceToken != useToken
                                if !useTokenValid then
                                  IO.eprintln "loam: use locus must be a nonempty single-line token"
                                  return 2
                                else if !useTokenDiffers then
                                  IO.eprintln "loam: spending source and use locus must differ"
                                  return 2
                                else
                                  match freshReplacementEventId? events, freshCorrectionId? corrections with
                                  | some replacementId, some correctionId =>
                                      let sourceEffect :=
                                        Loam.Core.Effect.ofQuantity
                                          ⟨"effect-1"⟩ ⟨sourceToken⟩ ⟨"jpy"⟩
                                          (Loam.Core.Quantity.ofQuanta (-amount))
                                      let effects :=
                                        match useToken? with
                                        | none => [sourceEffect]
                                        | some useToken =>
                                            let useEffect :=
                                              Loam.Core.Effect.ofQuantity
                                                ⟨"effect-2"⟩ ⟨useToken⟩ ⟨"jpy"⟩
                                                (Loam.Core.Quantity.ofQuanta amount)
                                            [sourceEffect, useEffect]
                                      match Loam.Core.Event.ofEffects? replacementId effects with
                                      | none =>
                                          IO.eprintln "loam: could not admit replacement event"
                                          return 2
                                      | some replacement =>
                                          let correction : Loam.Core.EventCorrection := {
                                            id := correctionId
                                            target := target.id
                                            replacement := replacement.id
                                          }
                                          match Loam.Core.EventMemory.add? events replacement,
                                              Loam.Core.EventCorrectionMemory.add? corrections correction with
                                          | some updatedEvents, some updatedCorrections =>
                                              if Loam.Core.EventCorrection.referencesPresent updatedEvents correction then
                                                if ← Loam.Persistence.saveEventCorrectionMemory? correctionFile updatedCorrections then
                                                  if ← Loam.Persistence.saveEventMemory? memoryFile updatedEvents then
                                                    match useToken? with
                                                    | none =>
                                                        IO.println
                                                          ("Correction recorded: " ++ toString amount ++
                                                            " jpy from " ++ sourceToken ++ ".")
                                                    | some useToken =>
                                                        IO.println
                                                          ("Correction recorded: " ++ toString amount ++
                                                            " jpy from " ++ sourceToken ++ " for " ++ useToken ++ ".")
                                                    IO.println
                                                      "Recorded quantities still include original and replacement facts; effective quantities are a separate projection."
                                                    return 0
                                                  else
                                                    IO.eprintln
                                                      "loam: replacement event was not published; the correction remains inactive until its referenced event is present"
                                                    return 2
                                                else
                                                  IO.eprintln "loam: correction contains an unrepresentable identity token"
                                                  return 2
                                              else
                                                IO.eprintln "loam: internal correction references are not closed"
                                                return 2
                                          | _, _ =>
                                              IO.eprintln "loam: could not append correction facts"
                                              return 2
                                  | _, _ =>
                                      IO.eprintln "loam: could not generate fresh correction identities"
                                      return 2
                              else
                                IO.eprintln "loam: amount must be a positive integer"
                                return 2
                        else
                          IO.eprintln "loam: payment source must be a nonempty single-line token"
                          return 2

/--
Correct one user-selected balanced JPY movement without rewriting its original
Event.

Selection recognizes only the same signed JPY shape admitted by the practical
movement entrance. The replacement is entered through that same FROM/TO adapter,
then appended as a generic Event and connected by the existing explicit
EventCorrection relation. Neither the candidate predicate nor the equality check
becomes a Core Event invariant.
-/
def correctMovement (memoryPath correctionPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  if !(← memoryFile.pathExists) then
    IO.eprintln "loam: nothing recorded yet"
    return 2
  else
    match ← Loam.Persistence.loadEventMemory? memoryFile with
    | none =>
        IO.eprintln "loam: malformed or unsupported event-memory file"
        return 2
    | some events =>
        match ← loadCorrectionMemoryForEntry? correctionFile with
        | none =>
            IO.eprintln "loam: malformed or unsupported correction-memory file"
            return 2
        | some corrections =>
            let candidates := correctableMovements events corrections
            match candidates with
            | [] =>
                IO.println "No movements are available to correct."
                return 0
            | _ =>
                IO.println "Which movement should be corrected?"
                printCandidates 1 candidates
                let selectionText ← promptLine "Select number: "
                match selectionText.toNat? with
                | none =>
                    IO.eprintln "loam: choose one of the displayed numbers"
                    return 2
                | some 0 =>
                    IO.eprintln "loam: choose one of the displayed numbers"
                    return 2
                | some selection =>
                    match getAt? candidates (selection - 1) with
                    | none =>
                        IO.eprintln "loam: choose one of the displayed numbers"
                        return 2
                    | some target =>
                        IO.println "Enter the corrected movement. Add FROM entries, then TO entries."
                        match ← Loam.MovementCli.collectMovementEffects with
                        | Except.error message =>
                            IO.eprintln message
                            return 2
                        | Except.ok (effects, total) =>
                            match freshReplacementEventId? events, freshCorrectionId? corrections with
                            | some replacementId, some correctionId =>
                                match Loam.Core.Event.ofEffects? replacementId effects with
                                | none =>
                                    IO.eprintln "loam: could not admit replacement movement"
                                    return 2
                                | some replacement =>
                                    let correction : Loam.Core.EventCorrection := {
                                      id := correctionId
                                      target := target.id
                                      replacement := replacement.id
                                    }
                                    match Loam.Core.EventMemory.add? events replacement,
                                        Loam.Core.EventCorrectionMemory.add? corrections correction with
                                    | some updatedEvents, some updatedCorrections =>
                                        if Loam.Core.EventCorrection.referencesPresent updatedEvents correction then
                                          if ← Loam.Persistence.saveEventCorrectionMemory? correctionFile updatedCorrections then
                                            if ← Loam.Persistence.saveEventMemory? memoryFile updatedEvents then
                                              IO.println
                                                ("Correction recorded: " ++ target.id.token ++ " -> " ++
                                                  replacement.id.token ++ " (" ++ toString total ++ " jpy).")
                                              IO.println
                                                "The original remains recorded; balance and effective views use the correction relation."
                                              return 0
                                            else
                                              IO.eprintln
                                                "loam: replacement event was not published; the correction remains inactive until its referenced event is present"
                                              return 2
                                          else
                                            IO.eprintln "loam: correction contains an unrepresentable identity token"
                                            return 2
                                        else
                                          IO.eprintln "loam: internal correction references are not closed"
                                          return 2
                                    | _, _ =>
                                        IO.eprintln "loam: could not append correction facts"
                                        return 2
                            | _, _ =>
                                IO.eprintln "loam: could not generate fresh correction identities"
                                return 2

end Loam.CorrectionCli