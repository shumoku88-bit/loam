import Loam.ActualValidityPersistence
import Loam.Application.ActualValidityFrontier
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

private def correctionMentionsEvent
    (corrections : Loam.Core.EventCorrectionMemory)
    (id : Loam.Core.EventId) : Bool :=
  corrections.corrections.any fun correction =>
    decide (correction.target = id) || decide (correction.replacement = id)

private def historyMentionsEvent
    (history : Loam.Core.ActualValidityHistory String)
    (id : Loam.Core.EventId) : Bool :=
  history.facts.any fun fact => decide (fact.event = id)

private def targetHasPublishedReplacement
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (id : Loam.Core.EventId) : Bool :=
  corrections.corrections.any fun correction =>
    decide (correction.target = id) &&
      (Loam.Core.EventMemory.findById? events correction.replacement).isSome

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
historical one-Effect record shape retained for compatibility.

A target whose replacement Event is already present is no longer offered. A
target with exactly one dangling correction relation remains selectable so an
interrupted relation-first publication can be resumed instead of becoming a
permanent dead end.
-/
private def correctableRecords
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory) : List Loam.Core.Event :=
  events.events.filter fun event =>
    (event.effects.length == 1 || balancedJpyMovement event.effects) &&
      !(targetHasPublishedReplacement events corrections event.id)

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
    (memory : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.EventId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.EventId := ⟨"replacement-" ++ toString index⟩
      match Loam.Core.EventMemory.findById? memory candidate with
      | some _ =>
          freshReplacementEventIdFrom memory corrections history (index + 1) fuel
      | none =>
          if correctionMentionsEvent corrections candidate || historyMentionsEvent history candidate then
            freshReplacementEventIdFrom memory corrections history (index + 1) fuel
          else
            some candidate

/--
Generate a replacement identity unused by every retained stream that can already
refer to an Event identity. This prevents a new correction from accidentally
closing an unrelated dangling correction or attaching an orphan date fact.
-/
private def freshReplacementEventId?
    (memory : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (history : Loam.Core.ActualValidityHistory String) : Option Loam.Core.EventId :=
  freshReplacementEventIdFrom memory corrections history 1
    (memory.events.length + 2 * corrections.corrections.length + history.facts.length + 1)

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

private def freshValidityFactIdFrom
    (history : Loam.Core.ActualValidityHistory String) :
    Nat → Nat → Option Loam.Core.ActualValidityFactId
  | _, 0 => none
  | index, fuel + 1 =>
      let candidate : Loam.Core.ActualValidityFactId :=
        ⟨"validity-" ++ toString index⟩
      match history.findFactById? candidate with
      | none => some candidate
      | some _ => freshValidityFactIdFrom history (index + 1) fuel

private def freshValidityFactId?
    (history : Loam.Core.ActualValidityHistory String) : Option Loam.Core.ActualValidityFactId :=
  freshValidityFactIdFrom history 1 (history.facts.length + 1)

private def loadCorrectionMemoryForEntry?
    (path : System.FilePath) : IO (Option Loam.Core.EventCorrectionMemory) := do
  if ← path.pathExists then
    Loam.Persistence.loadEventCorrectionMemory? path
  else
    return Loam.Core.EventCorrectionMemory.ofCorrections? []

private def currentValidityFactForEvent? :
    List (Loam.Core.ActualValidityFact String) →
    Loam.Core.EventId → Option (Loam.Core.ActualValidityFact String)
  | [], _ => none
  | fact :: rest, eventId =>
      if fact.event = eventId then some fact else currentValidityFactForEvent? rest eventId

private def targetingCorrections
    (corrections : Loam.Core.EventCorrectionMemory)
    (target : Loam.Core.EventId) : List Loam.Core.EventCorrection :=
  corrections.corrections.filter fun correction => decide (correction.target = target)

/--
Find the one relation-first publication that can be resumed for a selected
target. An already-published replacement is not resumable, and several sibling
relations remain ambiguous rather than acquiring retry-order authority.
-/
private def pendingCorrectionForTarget?
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (target : Loam.Core.EventId) : Except String (Option Loam.Core.EventCorrection) :=
  match targetingCorrections corrections target with
  | [] => Except.ok none
  | [correction] =>
      match Loam.Core.EventMemory.findById? events correction.replacement with
      | none => Except.ok (some correction)
      | some _ =>
          Except.error "loam: selected record already has a published replacement"
  | _ =>
      Except.error
        "loam: multiple correction relations target this record; no retry winner is implied"

/--
Carry the target Event's current occurrence date only as explicit evidence for
the replacement Event. EventCorrection itself never implies equal dates.

During retry, an already-published replacement date fact is accepted only when
it agrees with the target's still-current date. Missing target date evidence
stays missing rather than inventing a date for either Event.
-/
private def ensureReplacementValidity?
    (history : Loam.Core.ActualValidityHistory String)
    (currentFacts : List (Loam.Core.ActualValidityFact String))
    (targetFact? : Option (Loam.Core.ActualValidityFact String))
    (replacementId : Loam.Core.EventId) :
    Option (Loam.Core.ActualValidityHistory String × Bool) :=
  let replacementFact? := currentValidityFactForEvent? currentFacts replacementId
  match targetFact?, replacementFact? with
  | none, none => some (history, false)
  | none, some _ => none
  | some targetFact, some replacementFact =>
      if replacementFact.validOn = targetFact.validOn then
        some (history, false)
      else
        none
  | some targetFact, none => do
      let factId ← freshValidityFactId? history
      let fact : Loam.Core.ActualValidityFact String := {
        id := factId
        event := replacementId
        validOn := targetFact.validOn
      }
      let updated ← history.addFact? fact
      some (updated, true)

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
Finish publication for one already-chosen correction relation.

For a new correction, the raw relation is published first. If the target has a
current occurrence date, an independent replacement validity fact is published
next. The replacement Event is published last, so an interrupted earlier step
cannot make a partially evidenced replacement semantically current.

For retry, an existing dangling correction relation and any matching already-
published replacement date fact are reused. No cross-stream transaction or
arrival-order winner is introduced.
-/
private def publishWithCorrection
    (memoryFile correctionFile validityFile : System.FilePath)
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (history : Loam.Core.ActualValidityHistory String)
    (currentFacts : List (Loam.Core.ActualValidityFact String))
    (target : Loam.Core.Event)
    (effects : List Loam.Core.Effect)
    (correction : Loam.Core.EventCorrection)
    (appendCorrection : Bool) : IO (Except String Loam.Core.EventId) := do
  if correction.target != target.id then
    return Except.error "loam: internal retry correction target mismatch"
  else
    match Loam.Core.Event.ofEffects? correction.replacement effects with
    | none =>
        return Except.error "loam: could not admit replacement event"
    | some replacement =>
        match Loam.Core.EventMemory.add? events replacement with
        | none =>
            return Except.error "loam: could not append replacement event"
        | some updatedEvents =>
            let updatedCorrections? :=
              if appendCorrection then
                Loam.Core.EventCorrectionMemory.add? corrections correction
              else
                some corrections
            match updatedCorrections? with
            | none =>
                return Except.error "loam: could not append correction relation"
            | some updatedCorrections =>
                let targetFact? := currentValidityFactForEvent? currentFacts target.id
                match ensureReplacementValidity?
                    history currentFacts targetFact? replacement.id with
                | none =>
                    return Except.error
                      "loam: replacement occurrence-date evidence conflicts with the selected record"
                | some (updatedHistory, validityChanged) =>
                    if !Loam.Core.EventCorrection.referencesPresent updatedEvents correction then
                      return Except.error "loam: internal correction references are not closed"
                    else
                      let relationPublished ←
                        if appendCorrection then
                          Loam.Persistence.saveEventCorrectionMemory?
                            correctionFile updatedCorrections
                        else
                          pure true
                      if !relationPublished then
                        return Except.error
                          "loam: correction contains an unrepresentable identity token"
                      else
                        let validityPublished ←
                          if validityChanged then
                            Loam.Persistence.saveActualValidityHistory?
                              validityFile updatedHistory
                          else
                            pure true
                        if !validityPublished then
                          return Except.error
                            "loam: replacement occurrence-date evidence could not be published"
                        else if ← Loam.Persistence.saveEventMemory? memoryFile updatedEvents then
                          return Except.ok replacement.id
                        else
                          return Except.error
                            "loam: replacement event was not published; the correction remains resumable until its referenced event is present"

/--
Append or resume one replacement Event and one explicit EventCorrection without
rewriting the selected Event.

A fresh relation receives an Event identity unused by EventMemory, correction
endpoints, and ActualValidityHistory. A single dangling relation for the same
target is instead resumed with its already-chosen replacement identity.
-/
private def publishReplacement
    (memoryFile correctionFile validityFile : System.FilePath)
    (events : Loam.Core.EventMemory)
    (corrections : Loam.Core.EventCorrectionMemory)
    (history : Loam.Core.ActualValidityHistory String)
    (currentFacts : List (Loam.Core.ActualValidityFact String))
    (target : Loam.Core.Event)
    (effects : List Loam.Core.Effect) : IO (Except String Loam.Core.EventId) := do
  match pendingCorrectionForTarget? events corrections target.id with
  | Except.error message => return Except.error message
  | Except.ok (some pending) =>
      publishWithCorrection
        memoryFile correctionFile validityFile
        events corrections history currentFacts target effects pending false
  | Except.ok none =>
      match freshReplacementEventId? events corrections history, freshCorrectionId? corrections with
      | some replacementId, some correctionId =>
          let correction : Loam.Core.EventCorrection := {
            id := correctionId
            target := target.id
            replacement := replacementId
          }
          publishWithCorrection
            memoryFile correctionFile validityFile
            events corrections history currentFacts target effects correction true
      | _, _ =>
          return Except.error "loam: could not generate fresh correction identities"

/--
Human-facing entrance for correcting one user-selected recorded fact without
rewriting the original Event.

Balanced JPY movements are re-entered through the exact same FROM/TO adapter as
ordinary movement recording. Historical one-Effect records retain their old
correction input for compatibility. In both cases the original remains in raw
EventMemory and the replacement is related by one append-only EventCorrection.

If the selected Event has current Actual-validity evidence, the writer carries
that date forward only by publishing a new fact owned by the replacement Event.
That is writer convenience, not a theorem of EventCorrection. Relation and date
evidence are published before the Event so an interrupted write is safe and
resumable.

The function name `correctSpend` is retained for command compatibility while the
primary practical menu evolves from the older spending-only entrance.
-/
def correctSpend (memoryPath correctionPath : String) : IO UInt32 := do
  let memoryFile := System.FilePath.mk memoryPath
  let correctionFile := System.FilePath.mk correctionPath
  let validityFile := Loam.Persistence.actualValidityPathForEventMemory memoryFile
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
            match ← Loam.Persistence.loadActualValidityHistoryOrEmpty? validityFile with
            | none =>
                IO.eprintln "loam: malformed or unsupported actual-validity history"
                return 2
            | some history =>
                match Loam.Application.admittedActualValidityFacts? history with
                | none =>
                    IO.eprintln
                      "loam: actual-validity corrections do not justify one current date per event"
                    return 2
                | some currentFacts =>
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
                                          memoryFile correctionFile validityFile
                                          events corrections history currentFacts target effects with
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
                                          memoryFile correctionFile validityFile
                                          events corrections history currentFacts target effects with
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