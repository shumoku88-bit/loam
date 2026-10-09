import Loam.Authority.HouseholdAuthority
import Loam.Persistence.AttentionPersistence
import Loam.Tests.Support

namespace Loam.Tests.HouseholdAuthority

open Loam.Core
open Loam.Persistence.HouseholdImage

open Loam.Tests.Support

set_option autoImplicit false

/-- Returning the admitted image preserves the previous Actual codec's acceptance exactly. -/
example (wire : String) :
    (Loam.Persistence.decodeNormalizedActualImage? wire).isSome =
      (Loam.Persistence.decodeNormalizedActual? wire).isSome := by
  unfold Loam.Persistence.decodeNormalizedActualImage?
    Loam.Persistence.decodeNormalizedActual? Loam.Persistence.decodeNormalizedActualDetailed
  cases Loam.Persistence.decodeNormalizedActualImageDetailed wire <;> rfl

private def emptyAttention : IO String := do
  let items ← requireSome
    (AttentionMemory.ofItems? [])
    "empty Attention memory was rejected"
  let closures ← requireSome
    (AttentionClosureMemory.ofClosures? [])
    "empty Attention closure memory was rejected"
  requireSome
    (Loam.Persistence.encodeAttentionMemory? items closures)
    "empty Attention memory did not encode"

private def oneAttention : IO String := do
  let item : Attention String := {
    id := ⟨"attention-1"⟩
    context := "watch refund"
    due := .noDueDate
  }
  let items ← requireSome
    (AttentionMemory.ofItems? [item])
    "one Attention item was rejected"
  let closures ← requireSome
    (AttentionClosureMemory.ofClosures? [])
    "empty Attention closures were rejected"
  requireSome
    (Loam.Persistence.encodeAttentionMemory? items closures)
    "one Attention item did not encode"

private def cleanupDir (root : System.FilePath) : IO Unit := do
  if ← root.pathExists then
    IO.FS.removeDirAll root

def main (args : List String) : IO Unit := do
  let [rootPath] := args
    | throw (IO.userError "supply isolated HouseholdAuthority test directory")
  let root := System.FilePath.mk rootPath
  cleanupDir root
  IO.FS.createDirAll root

  let attentionA ← emptyAttention
  let attentionB ← oneAttention
  let futureBody := "FUTURE\t1\nopaque\tunknown\n"

  let base : Image := {
    sections := [
      { name := "Attention", body := attentionA },
      { name := "Securities", body := futureBody }
    ]
  }

  -- P2 must not select or mutate the legacy authority layout.
  let legacyActual := root / "actual.loam"
  IO.FS.writeFile legacyActual "legacy-authority-sentinel\n"

  let installed ← requireOk
    (← Loam.HouseholdAuthority.installInitial? root base)
    "initial HouseholdImage installation failed"
  expect (installed.image == base)
    "initial HouseholdImage installation changed the candidate"
  expect (← (Loam.HouseholdAuthority.path root).pathExists)
    "initial HouseholdImage installation did not create household.loam"
  expect ((← IO.FS.readFile legacyActual) == "legacy-authority-sentinel\n")
    "initial HouseholdImage installation mutated legacy Actual"

  let loadedA ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "installed HouseholdImage did not load"
  expect (loadedA.image == base)
    "loaded initial HouseholdImage differs from installed image"
  expect (body? loadedA.image "Capacity" == none)
    "HouseholdAuthority invented an absent known section"
  let (pairedA, absentActual) ← requireOk
    (← Loam.HouseholdAuthority.loadCurrentWithActual? root) "paired absent Actual load"
  expect (pairedA.wire == loadedA.wire && absentActual.isNone)
    "paired load invented Actual or changed the selected generation"

  -- Retaining Actual from qualification must not bypass any other known family.
  let actualRoot := root / "paired-actual"
  IO.FS.createDirAll actualRoot
  let actualBody ← requireSome
    (Loam.Persistence.encodeNormalizedActual? Loam.ActualEvidence.empty) "empty Actual codec"
  let actualCandidate ← requireSome
    (appendSection? base { name := "Actual", body := actualBody }) "paired Actual fixture"
  let actualInstalled ← requireOk
    (← Loam.HouseholdAuthority.installInitial? actualRoot actualCandidate) "paired Actual install"
  let (paired, actual?) ← requireOk
    (← Loam.HouseholdAuthority.loadCurrentWithActual? actualRoot) "paired admitted Actual load"
  let actual ← requireSome actual? "paired load lost present admitted Actual"
  expect (paired.wire == actualInstalled.wire && actual.evidence.events.events.isEmpty)
    "paired load drifted from the qualified generation"
  for (name, badBody) in [("Attention", "malformed attention\n"), ("Actual", "malformed actual\n")] do
    let bad ← requireSome (replaceBody? actualCandidate name badBody) "paired malformed fixture"
    let badWire ← requireSome (Loam.Persistence.HouseholdImage.encode? bad) "paired malformed wire"
    IO.FS.writeFile (Loam.HouseholdAuthority.path actualRoot) badWire
    match ← Loam.HouseholdAuthority.loadCurrentWithActual? actualRoot with
    | .error _ => pure ()
    | .ok _ => throw (IO.userError ("paired Actual load bypassed malformed " ++ name))

  match ← Loam.HouseholdAuthority.installInitial? root base with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "second initial HouseholdImage installation unexpectedly succeeded")

  -- A partial candidate stage is inert until the authority rename.
  let stage :=
    System.FilePath.mk ((Loam.HouseholdAuthority.path root).toString ++ ".loam-stage")
  IO.FS.writeFile stage "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tAttention\t999\npartial"
  let afterPartial ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "partial stage disturbed current HouseholdImage"
  expect (afterPartial.wire == loadedA.wire)
    "partial stage changed current generation bytes"

  let candidateB ← requireSome
    (replaceBody? base "Attention" attentionB)
    "Attention section replacement failed"

  let publishedB ← requireOk
    (← Loam.HouseholdAuthority.publishObserved?
      root loadedA.wire ["Attention"] candidateB)
    "Attention-only HouseholdImage publication failed"
  expect (body? publishedB.image "Attention" == some attentionB)
    "Attention-only publication did not install changed Attention"
  expect (body? publishedB.image "Securities" == some futureBody)
    "Attention-only publication changed unknown future evidence"
  expect (body? publishedB.image "Capacity" == none)
    "Attention-only publication invented an absent known section"

  let previousWire ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath root)
  expect (previousWire == loadedA.wire)
    "previous HouseholdImage did not retain generation A"

  -- Unknown future evidence cannot be modified through a known-section write.
  let tamperedFuture : Image := {
    sections := candidateB.sections.map fun part =>
      if part.name == "Securities" then
        { part with body := "tampered\n" }
      else
        part
  }
  match ← Loam.HouseholdAuthority.publishObserved?
      root publishedB.wire ["Attention"] tamperedFuture with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "publication changed unmarked unknown future evidence")

  match ← Loam.HouseholdAuthority.publishObserved?
      root publishedB.wire ["Securities"] tamperedFuture with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "unknown section identity was accepted as a writable semantic family")

  -- A writer that observed A cannot replace B.
  let staleCandidate ← requireSome
    (replaceBody? base "Attention" attentionB)
    "stale candidate construction failed"
  match ← Loam.HouseholdAuthority.publishObserved?
      root loadedA.wire ["Attention"] staleCandidate with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "stale HouseholdImage writer unexpectedly published")
  let stillB ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "current HouseholdImage disappeared after stale writer"
  expect (stillB.wire == publishedB.wire)
    "stale writer changed current HouseholdImage"

  -- Malformed changed semantics fail before authority replacement.
  let malformedAttention := "LOAM-ATTENTION-MEMORY\t1\nITEM\tbroken\n"
  let malformedCandidate ← requireSome
    (replaceBody? candidateB "Attention" malformedAttention)
    "malformed Attention candidate construction failed"
  match ← Loam.HouseholdAuthority.publishObserved?
      root publishedB.wire ["Attention"] malformedCandidate with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "malformed changed section unexpectedly published")
  let afterMalformed ← requireOk
    (← Loam.HouseholdAuthority.loadCurrent? root)
    "malformed publication disturbed current HouseholdImage"
  expect (afterMalformed.wire == publishedB.wire)
    "malformed changed section altered current HouseholdImage"

  -- Corrupt current is recoverable from previous, and the source is explicit.
  IO.FS.writeFile (Loam.HouseholdAuthority.path root)
    "LOAM-HOUSEHOLD-IMAGE\t2\nSECTION\tAttention\t999\ntruncated"
  let recovered ← requireOk
    (← Loam.HouseholdAuthority.loadRecoverable? root)
    "corrupt current had no recoverable previous generation"
  expect (recovered.source == .previous)
    "recoverable load silently presented previous evidence as current"
  expect (recovered.generation.wire == loadedA.wire)
    "recoverable load selected unexpected previous generation"

  let restored ← requireOk
    (← Loam.HouseholdAuthority.restorePrevious? root)
    "explicit previous-generation restore failed"
  expect (restored.wire == loadedA.wire)
    "explicit restore did not reinstall generation A"

  -- Outer framing can be valid while one known inner section is malformed.
  let badInner ← requireSome
    (replaceBody? base "Attention" malformedAttention)
    "outer-valid malformed-inner fixture construction failed"
  let badInnerWire ← requireSome
    (Loam.Persistence.HouseholdImage.encode? badInner)
    "outer-valid malformed-inner fixture did not encode"
  expect (Loam.Persistence.HouseholdImage.decode? badInnerWire).isSome
    "malformed-inner fixture unexpectedly broke outer framing"
  IO.FS.writeFile (Loam.HouseholdAuthority.path root) badInnerWire

  let recoveredInner ← requireOk
    (← Loam.HouseholdAuthority.loadRecoverable? root)
    "outer-valid malformed-inner current had no recoverable previous"
  expect (recoveredInner.source == .previous)
    "inner-malformed current did not expose previous recovery source"
  expect (recoveredInner.generation.wire == loadedA.wire)
    "inner-malformed recovery selected unexpected generation"

  expect ((← IO.FS.readFile legacyActual) == "legacy-authority-sentinel\n")
    "HouseholdAuthority qualification mutated legacy Actual"

  cleanupDir root
  IO.println
    "HouseholdAuthority: install, one-lock publication, stale refusal, unknown preservation, explicit recovery, and legacy isolation passed."

end Loam.Tests.HouseholdAuthority

def main (args : List String) : IO Unit :=
  Loam.Tests.HouseholdAuthority.main args
