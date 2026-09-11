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
  let occurrence1 : ScheduledOccurrence String := {
    id := ⟨"scheduled-1"⟩
    scheduledOn := "2026-09-10"
    movement := movement }
  let occurrence2 : ScheduledOccurrence String := {
    id := ⟨"scheduled-2"⟩
    scheduledOn := "2026-09-11"
    movement := movement }
  let occurrence3 : ScheduledOccurrence String := {
    id := ⟨"scheduled-3"⟩
    scheduledOn := "2026-09-12"
    movement := movement }
  let some scheduled := ScheduledMemory.ofOccurrences?
      [occurrence1, occurrence2, occurrence3]
    | throw (IO.userError "scheduled memory")
  let terminalsRaw : List ScheduledTerminal :=
    [ { source := ⟨"scheduled-1"⟩,
        target := some (.scheduled ⟨"scheduled-2"⟩) }
    , { source := ⟨"scheduled-2"⟩,
        target := some (.actual ⟨"actual-2"⟩) }
    , { source := ⟨"scheduled-3"⟩,
        target := none }
    ]
  let some terminals := ScheduledTerminalMemory.ofTerminals? terminalsRaw
    | throw (IO.userError "terminal memory")
  return { scheduled, terminals }

private def emptySpecimen : IO Loam.Persistence.ScheduledLifecycleImage := do
  let some scheduled := ScheduledMemory.ofOccurrences? []
    | throw (IO.userError "empty scheduled memory")
  let some terminals := ScheduledTerminalMemory.ofTerminals? []
    | throw (IO.userError "empty terminal memory")
  return { scheduled, terminals }

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
      decodedEmpty.terminals.terminals.isEmpty)
    "explicit empty lifecycle lost semantic emptiness"
  expect (emptyText.contains "BEGIN\tCompletion\n" &&
      emptyText.contains "BEGIN\tRetirement\n" &&
      emptyText.contains "BEGIN\tReplacement\n")
    "semantic recompression changed the v1 physical section contract"

  let image ← specimen
  let some encoded := Loam.Persistence.encodeScheduledLifecycleImage? image
    | throw (IO.userError "encode lifecycle specimen")
  let some decoded := Loam.Persistence.decodeScheduledLifecycleImage? encoded
    | throw (IO.userError "decode lifecycle specimen")
  expect (decoded.scheduled.occurrences.length == 3)
    "Scheduled occurrences did not round-trip"
  expect (decoded.terminals.terminals.length == 3)
    "terminal meanings did not round-trip"
  expect (decoded.terminals.replacementFor? ⟨"scheduled-1"⟩ == some ⟨"scheduled-2"⟩)
    "replacement endpoint identity changed on round-trip"
  expect (decoded.terminals.completionActualFor? ⟨"scheduled-2"⟩ == some ⟨"actual-2"⟩)
    "completion endpoint identity changed on round-trip"
  expect ((decoded.terminals.retirementFor? ⟨"scheduled-3"⟩).isSome)
    "retirement meaning changed on round-trip"

  expect (encoded.contains
      "COMPLETION\tscheduled-2\tactual-2")
    "v1 Completion row disappeared during semantic recompression"
  expect (encoded.contains "RETIREMENT\tscheduled-3")
    "v1 Retirement row disappeared during semantic recompression"
  expect (encoded.contains
      "REPLACEMENT\tscheduled-1\tscheduled-2")
    "v1 Replacement row disappeared during semantic recompression"

  let replacementSection :=
    "BEGIN\tReplacement\n" ++
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\n" ++
    "REPLACEMENT\tscheduled-1\tscheduled-2\n" ++
    "END\tReplacement\n"
  let duplicateSourceSection :=
    "BEGIN\tReplacement\n" ++
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\n" ++
    "REPLACEMENT\tscheduled-1\tscheduled-2\n" ++
    "REPLACEMENT\tscheduled-1\tscheduled-3\n" ++
    "END\tReplacement\n"
  let duplicateSource := encoded.replace replacementSection duplicateSourceSection
  expect ((Loam.Persistence.decodeScheduledLifecycleImage? duplicateSource).isNone)
    "duplicate replacement source was admitted by the inline lifecycle decoder"

  let duplicateTargetSection :=
    "BEGIN\tReplacement\n" ++
    "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\n" ++
    "REPLACEMENT\tscheduled-1\tscheduled-3\n" ++
    "REPLACEMENT\tscheduled-2\tscheduled-3\n" ++
    "END\tReplacement\n"
  let duplicateTarget := encoded.replace replacementSection duplicateTargetSection
  expect ((Loam.Persistence.decodeScheduledLifecycleImage? duplicateTarget).isNone)
    "shared replacement endpoint was admitted by the inline lifecycle decoder"

  expect (← Loam.Persistence.saveScheduledLifecycleImage? authority image)
    "publish lifecycle specimen"
  let some reloaded ← Loam.Persistence.loadScheduledLifecycleImage? authority
    | throw (IO.userError "reload published lifecycle")
  expect (reloaded.scheduled.occurrences.length == 3 &&
      reloaded.terminals.terminals.length == 3)
    "published lifecycle did not reload its semantic terminal relation"

  let completionSection :=
    "BEGIN\tCompletion\n" ++
    "LOAM-SCHEDULED-COMPLETION-MEMORY\t1\n" ++
    "COMPLETION\tscheduled-2\tactual-2\n" ++
    "END\tCompletion\n"
  let withoutCompletionSection := encoded.replace completionSection ""
  expect ((Loam.Persistence.decodeScheduledLifecycleImage?
      withoutCompletionSection).isNone)
    "missing v1 Completion section was interpreted as explicit empty"

  let malformedOrder := encoded.replace "BEGIN\tRetirement\n" "BEGIN\tWrong\n"
  expect ((Loam.Persistence.decodeScheduledLifecycleImage? malformedOrder).isNone)
    "malformed lifecycle section marker was admitted"

  IO.println "Scheduled Lifecycle Persistence: one semantic terminal relation directly preserves v1 Completion/Retirement/Replacement wire meaning, endpoint uniqueness, explicit empty, and fail-closed authority."
