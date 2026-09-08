import Loam.Persistence.ScheduledLifecyclePersistence

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def movement? (amount : Int) : Option (BalancedMovement LocusId) :=
  BalancedMovement.ofChanges? ⟨"jpy"⟩
    [ { coordinate := ⟨"smbc"⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨"rent"⟩, quantity := Quantity.ofQuanta amount }
    ]

private def specimen : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some movement := movement? 1000 | throw (IO.userError "movement")
  let occurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-1"⟩
    scheduledOn := "2026-09-10"
    movement := movement }
  let replacementOccurrence : ScheduledOccurrence String := {
    id := ⟨"scheduled-2"⟩
    scheduledOn := "2026-09-11"
    movement := movement }
  let some scheduled := ScheduledMemory.ofOccurrences? [occurrence, replacementOccurrence]
    | throw (IO.userError "scheduled memory")
  let some completions := ScheduledCompletionMemory.ofCompletions?
      [{ scheduled := ⟨"scheduled-2"⟩, actual := ⟨"actual-2"⟩ }]
    | throw (IO.userError "completion memory")
  let some retirements := ScheduledRetirementMemory.ofRetirements? []
    | throw (IO.userError "retirement memory")
  let some replacements := ScheduledReplacementMemory.ofReplacements?
      [{ source := ⟨"scheduled-1"⟩, replacement := ⟨"scheduled-2"⟩ }]
    | throw (IO.userError "replacement memory")
  return { scheduled, completions, retirements, replacements }

private def emptySpecimen : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty scheduled memory")
  let some completions := ScheduledCompletionMemory.ofCompletions? []
    | throw (IO.userError "empty completion memory")
  let some retirements := ScheduledRetirementMemory.ofRetirements? []
    | throw (IO.userError "empty retirement memory")
  let some replacements := ScheduledReplacementMemory.ofReplacements? []
    | throw (IO.userError "empty replacement memory")
  return { scheduled, completions, retirements, replacements }

def main (args : List String) : IO Unit := do
  let [dataPath] := args | throw (IO.userError "supply isolated data directory")
  let dataDir := System.FilePath.mk dataPath
  IO.FS.createDirAll dataDir
  let authority := dataDir / "scheduled.loam"

  let missing ← Loam.Persistence.loadScheduledLifecycleImage? authority
  expect missing.isNone "missing lifecycle authority did not fail closed"

  let empty ← emptySpecimen
  let some emptyText := Loam.Persistence.encodeScheduledLifecycleImage? empty
    | throw (IO.userError "encode explicit empty lifecycle")
  let some decodedEmpty := Loam.Persistence.decodeScheduledLifecycleImage? emptyText
    | throw (IO.userError "decode explicit empty lifecycle")
  expect (decodedEmpty.scheduled.occurrences.isEmpty &&
      decodedEmpty.completions.completions.isEmpty &&
      decodedEmpty.retirements.retirements.isEmpty &&
      decodedEmpty.replacements.replacements.isEmpty)
    "explicit empty lifecycle lost an empty facet"

  let image ← specimen
  let some encoded := Loam.Persistence.encodeScheduledLifecycleImage? image
    | throw (IO.userError "encode lifecycle specimen")
  let some decoded := Loam.Persistence.decodeScheduledLifecycleImage? encoded
    | throw (IO.userError "decode lifecycle specimen")
  expect (decoded.scheduled.occurrences.length == 2)
    "Scheduled facet did not round-trip"
  expect (decoded.completions.completions.length == 1)
    "Completion facet did not round-trip"
  expect (decoded.retirements.retirements.isEmpty)
    "Retirement empty facet did not round-trip"
  expect (decoded.replacements.replacements.length == 1)
    "Replacement facet did not round-trip"
  expect ((ScheduledReplacementMemory.findBySource?
      decoded.replacements ⟨"scheduled-1"⟩).isSome)
    "replacement endpoint identity changed on round-trip"

  expect (← Loam.Persistence.saveScheduledLifecycleImage? authority image)
    "publish lifecycle specimen"
  let some reloaded ← Loam.Persistence.loadScheduledLifecycleImage? authority
    | throw (IO.userError "reload published lifecycle")
  expect (reloaded.scheduled.occurrences.length == 2 &&
      reloaded.completions.completions.length == 1 &&
      reloaded.replacements.replacements.length == 1)
    "published lifecycle did not reload all facets"

  let withoutCompletionSection :=
    encoded.replace
      ("BEGIN\tCompletion\n" ++
       (Loam.Persistence.encodeScheduledCompletionMemory? image.completions).getD "" ++
       "END\tCompletion\n") ""
  expect ((Loam.Persistence.decodeScheduledLifecycleImage?
      withoutCompletionSection).isNone)
    "missing Completion section was interpreted as explicit empty"

  let malformedOrder := encoded.replace "BEGIN\tRetirement\n" "BEGIN\tWrong\n"
  expect ((Loam.Persistence.decodeScheduledLifecycleImage? malformedOrder).isNone)
    "malformed lifecycle section marker was admitted"

  IO.println "Scheduled Lifecycle Persistence: explicit empty, full typed round-trip, missing authority and missing-section refusal passed."
