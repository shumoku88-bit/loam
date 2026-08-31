import Loam.Core.RelationAdmission
import Loam.Persistence
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

private def correctableEvents
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory) : List Loam.Core.Event :=
  events.events.filter fun event =>
    event.effects.length == 1 && !(targetsEvent corrections.corrections event.id)

private def printCandidates : Nat → List Loam.Core.Event → IO Unit
  | _, [] => pure ()
  | index, event :: rest => do
      match event.effects with
      | [effect] =>
          IO.println
            (toString index ++ ". " ++ effect.locus.token ++ ": " ++
              toString effect.quantity.quanta ++ " " ++ effect.measure.token ++
              "  [" ++ event.id.token ++ "]")
      | _ => pure ()
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

/--
Human-facing entrance for correcting one spend-shaped recorded Event without
rewriting the original Event.

The selected original remains in EventMemory. The corrected interpretation is a
new Event, connected by one explicit EventCorrection in a separate raw relation
stream. The relation stream is published first; until its replacement Event is
also present, referential admission keeps the dangling relation semantically
inactive. No arrival-order or last-write-wins rule is introduced.
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
                IO.println "No one-effect records are available to correct."
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
                        let locusToken ← promptLine "Paid from? "
                        if Loam.Persistence.validToken locusToken then
                          let amountText ← promptLine "Amount? "
                          match amountText.toInt? with
                          | none =>
                              IO.eprintln "loam: amount must be a positive integer"
                              return 2
                          | some amount =>
                              if amount > 0 then
                                match freshReplacementEventId? events, freshCorrectionId? corrections with
                                | some replacementId, some correctionId =>
                                    let effect :=
                                      Loam.Core.Effect.ofQuantity
                                        ⟨"effect-1"⟩ ⟨locusToken⟩ ⟨"jpy"⟩
                                        (Loam.Core.Quantity.ofQuanta (-amount))
                                    match Loam.Core.Event.ofEffects? replacementId [effect] with
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
                                                  IO.println
                                                    ("Correction recorded: " ++ toString amount ++
                                                      " jpy from " ++ locusToken ++ ".")
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

end Loam.CorrectionCli
