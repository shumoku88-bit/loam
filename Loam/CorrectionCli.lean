import Loam.Core.RelationAdmission
import Loam.Persistence
import Loam.MovementEntry
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
            let nextNegative := if quantity < 0 then true else hasNegative
            let nextPositive := if quantity > 0 then true else hasPositive
            some (total + quantity, nextNegative, nextPositive)

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

/--
The primary correction entrance accepts current balanced movements plus the
historical one-Effect record shape retained for compatibility. Selecting a
balanced Event does not classify it as spending, transfer, or any other kind;
the human is selecting the fact they intend to replace.
-/
private def correctableRecords
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory) : List Loam.Core.Event :=
  events.events.filter fun event =>
    (event.effects.length == 1 || balancedJpyMovement event.effects) &&
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
Collect the historical one-Effect correction input, while retaining the later
interactive source/use form for old spend-shaped records. The returned String is
the compatibility success message used after publication.
-/
private def collectHistoricalReplacement :
    IO (Except String (List Loam.Core.Effect × Int × String)) := do
  let sourceToken ← promptLine "Paid from? "
  if !Loam.Persistence.validToken sourceToken then
    return Except.error "loam: payment source must be a nonempty single-line token"
  else
    let useOrAmount ← promptLine "Used for? "
    let amountText ← promptLine "Amount? "
    match spendEntry? useOrAmount amountText with
    | none =>
        return Except.error "loam: amount must be a positive integer"
    | some (useToken?, amount) =>
        if amount <= 0 then
          return Except.error "loam: amount must be a positive integer"
        else
          let useTokenValid :=
            match useToken? with
            | none => true
            | some useToken => Loam.Persistence.validToken useToken
          let useTokenDiffers :=
            match useToken? with
            | none => true
            | some useToken => sourceToken != useToken
          if !useTokenValid then
            return Except.error "loam: use locus must be a nonempty single-line token"
          else if !useTokenDiffers then
            return Except.error "loam: spending source and use locus must differ"
          else
            let sourceEffect :=
              Loam.Core.Effect.ofQuantity
                ⟨"effect-1"⟩ ⟨sourceToken⟩ ⟨"jpy"⟩
                (Loam.Core.Quantity.ofQuanta (-amount))
            match useToken? with
            | none =>
                return Except.ok
                  ( [sourceEffect], amount,
                    "Correction recorded: " ++ toString amount ++
                      " jpy from " ++ sourceToken ++ "." )
            | some useToken =>
                let useEffect :=
                  Loam.Core.Effect.ofQuantity
                    ⟨"effect-2"⟩ ⟨useToken⟩ ⟨"jpy"⟩
                    (Loam.Core.Quantity.ofQuanta amount)
                return Except.ok
                  ( [sourceEffect, useEffect], amount,
                    "Correction recorded: " ++ toString amount ++
                      " jpy from " ++ sourceToken ++ " for " ++ useToken ++ "." )

/--
Append one replacement Event and one explicit EventCorrection without rewriting
the selected Event. The relation stream is published first; until its replacement
Event is also present, referential admission keeps the dangling relation
semantically inactive. No arrival-order or last-write-wins rule is introduced.
-/
private def publishReplacement
    (memoryFile correctionFile : System.FilePath)
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (target : Loam.Core.Event)
    (effects : List Loam.Core.Effect) : IO (Except String Loam.Core.EventId) := do
  match freshReplacementEventId? events, freshCorrectionId? corrections with
  | some replacementId, some correctionId =>
      match Loam.Core.Event.ofEffects? replacementId effects with
      | none =>
          return Except.error "loam: could not admit replacement event"
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
                    return Except.ok replacement.id
                  else
                    return Except.error
                      "loam: replacement event was not published; the correction remains inactive until its referenced event is present"
                else
                  return Except.error "loam: correction contains an unrepresentable identity token"
              else
                return Except.error "loam: internal correction references are not closed"
          | _, _ =>
              return Except.error "loam: could not append correction facts"
  | _, _ =>
      return Except.error "loam: could not generate fresh correction identities"

/--
Human-facing entrance for correcting one user-selected recorded fact without
rewriting the original Event.

Balanced JPY movements are re-entered through the exact same FROM/TO adapter as
ordinary movement recording. Historical one-Effect records retain their old
correction input for compatibility. In both cases the original remains in raw
EventMemory and the replacement is related by one append-only EventCorrection.
The movement equality rule remains an interface rule rather than a Core Event
invariant.

The function name `correctSpend` is retained for command compatibility while the
primary practical menu evolves from the older spending-only entrance.
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
            let candidates := correctableRecords events corrections
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
                        if target.effects.length == 1 then
                          match ← collectHistoricalReplacement with
                          | Except.error message =>
                              IO.eprintln message
                              return 2
                          | Except.ok (effects, _, successMessage) =>
                              match ← publishReplacement
                                  memoryFile correctionFile events corrections target effects with
                              | Except.error message =>
                                  IO.eprintln message
                                  return 2
                              | Except.ok _ =>
                                  IO.println successMessage
                                  IO.println
                                    "Recorded quantities still include original and replacement facts; effective quantities are a separate projection."
                                  return 0
                        else
                          IO.println "Enter the corrected movement. Add FROM entries, then TO entries."
                          match ← Loam.MovementEntry.collectMovementEffects with
                          | Except.error message =>
                              IO.eprintln message
                              return 2
                          | Except.ok (effects, total) =>
                              match ← publishReplacement
                                  memoryFile correctionFile events corrections target effects with
                              | Except.error message =>
                                  IO.eprintln message
                                  return 2
                              | Except.ok replacementId =>
                                  IO.println
                                    ("Correction recorded: " ++ target.id.token ++ " -> " ++
                                      replacementId.token ++ " (" ++ toString total ++ " jpy).")
                                  IO.println
                                    "The original remains recorded; balance and effective views use the correction relation."
                                  return 0

end Loam.CorrectionCli