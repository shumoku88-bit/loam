import Loam.Authority.ActualAuthority
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.NormalizedActualPersistence

namespace Loam.Tests.HouseholdActualAuthority

open Loam.Core
open Loam.Persistence.HouseholdImage

set_option autoImplicit false

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private def requireOk {α : Type} (value : Except String α) (message : String) : IO α :=
  match value with
  | .ok result => pure result
  | .error detail => throw (IO.userError (message ++ ": " ++ detail))

private def wire (id : String) (amount : Int) : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++
  s!"TX\t{id}\t2026-10-04\tNODESC\n" ++
  s!"EFFECT\twallet\tjpy\t{-amount}\n" ++
  s!"EFFECT\tincome\tjpy\t{amount}\n" ++
  "ENDTX\n"

def main : IO Unit := do
  let root ← IO.FS.createTempDir
  let actualA := wire "ev-a" 100
  let actualB := wire "ev-b" 200
  let actualC := wire "ev-c" 300
  let futureBody := "FUTURE\t1\nopaque\tkeep-me\n"

  let installed ←
    requireOk
      (← Loam.HouseholdAuthority.installInitial? root {
        sections := [
          { name := "Actual", body := actualA },
          { name := "Securities", body := futureBody }
        ]
      })
      "install Household Actual qualification fixture"

  -- Keep a valid but conflicting standalone Actual beside HouseholdImage.
  IO.FS.writeFile (Loam.ActualAuthority.actualPath root) actualC
  let frozenLegacy ← IO.FS.readFile (Loam.ActualAuthority.actualPath root)

  let observedA ←
    requireOk
      (← Loam.ActualAuthority.loadHouseholdObserved? root)
      "load Household Actual A"
  expect
    ((observedA.image.currentEvents.findById? ⟨"ev-a"⟩).isSome)
    "Household Actual adapter did not select the Household section"
  expect
    ((observedA.image.currentEvents.findById? ⟨"ev-c"⟩).isNone)
    "stale standalone Actual leaked into Household selection"

  -- P11a is qualification only: the old standalone root loader is unchanged.
  let legacyImage ←
    requireOk (← Loam.ActualAuthority.loadImage? root)
      "load unchanged standalone Actual authority"
  expect
    ((legacyImage.currentEvents.findById? ⟨"ev-c"⟩).isSome)
    "P11a unexpectedly changed the existing standalone production loader"

  let evidenceB ←
    requireSome
      (Loam.Persistence.decodeNormalizedActual? actualB)
      "decode proposed Household Actual B"
  let publishedB ←
    requireOk
      (← Loam.ActualAuthority.publishHouseholdObserved? root observedA evidenceB)
      "publish Household Actual B"
  let bodyB ←
    requireSome (body? publishedB.image "Actual")
      "published Household generation lost Actual"
  expect (bodyB == actualB)
    "Household Actual publication did not install proposed Actual"
  expect (body? publishedB.image "Securities" == some futureBody)
    "Household Actual publication changed unknown future evidence"
  expect
    ((← IO.FS.readFile (Loam.ActualAuthority.actualPath root)) == frozenLegacy)
    "Household Actual publication changed frozen standalone actual.loam"

  let previous ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath root)
  expect (previous == installed.wire)
    "Household Actual publication did not retain the observed generation in .prev"

  let evidenceC ←
    requireSome
      (Loam.Persistence.decodeNormalizedActual? actualC)
      "decode stale-writer Household Actual C"
  match ← Loam.ActualAuthority.publishHouseholdObserved? root observedA evidenceC with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "stale Household Actual writer unexpectedly published")

  let stillB ←
    requireOk
      (← Loam.ActualAuthority.loadHouseholdImage? root)
      "reload Household Actual after stale refusal"
  expect
    ((stillB.currentEvents.findById? ⟨"ev-b"⟩).isSome)
    "stale Household Actual writer changed current generation"

  let missingRoot ← IO.FS.createTempDir
  let _ ←
    requireOk
      (← Loam.HouseholdAuthority.installInitial? missingRoot {
        sections := [{ name := "Securities", body := futureBody }]
      })
      "install missing-Actual Household fixture"
  match ← Loam.ActualAuthority.loadHouseholdImage? missingRoot with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "missing Household Actual section was treated as empty")

  let malformedRoot ← IO.FS.createTempDir
  let malformedOuter ←
    requireSome
      (Loam.Persistence.HouseholdImage.encode? {
        sections := [{ name := "Actual", body := "not-normalized-actual\n" }]
      })
      "encode outer-valid malformed Actual fixture"
  IO.FS.writeFile (Loam.HouseholdAuthority.path malformedRoot) malformedOuter
  match ← Loam.ActualAuthority.loadHouseholdImage? malformedRoot with
  | .error _ => pure ()
  | .ok _ =>
      throw (IO.userError "malformed present Household Actual section did not fail closed")

  IO.println
    "Household Actual authority qualification: required/fail-closed selection, stale refusal, .prev, unknown preservation, and standalone isolation passed."

end Loam.Tests.HouseholdActualAuthority

def main : IO Unit :=
  Loam.Tests.HouseholdActualAuthority.main
