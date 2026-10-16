import Loam.Authority.AnnualSandboxDurabilityBarriers
import Loam.Persistence.LocusAdmissionPersistence

namespace Loam.Tools.NativeAnnualCopyRestoreProbe

open Loam.Core
open Loam.Persistence.HouseholdImage
set_option autoImplicit false

private def requireOk {α : Type} (x : Except String α)
    (label : String) : IO α := do
  match x with
  | .ok value => return value
  | .error reason => throw (IO.userError s!"{label}: {reason}")

private def requireSome {α : Type} (x : Option α)
    (label : String) : IO α := do
  let some value := x | throw (IO.userError label)
  return value

private def expect (ok : Bool) (why : String) : IO Unit := do
  unless ok do throw (IO.userError why)

private def load (path : String) : IO Loam.HouseholdAuthority.Generation := do
  requireOk (Loam.AnnualSourceMaterialization.qualifyWire?
    (← IO.FS.readFile (System.FilePath.mk path))) "qualified fixture"

private def withLoci (generation : Loam.HouseholdAuthority.Generation)
    (names : List String) : IO Image := do
  let locus ← requireSome
    (LocusAdmissionVocabulary.ofLoci? (names.map fun n => ⟨n⟩))
    "synthetic locus vocabulary"
  let body ← requireSome
    (Loam.Persistence.encodeLocusAdmissionVocabulary? locus) "locus encoding"
  requireSome (replaceBody? generation.image "LocusAdmission" body)
    "existing native locus section"

private def selected (root : System.FilePath) :
    IO Loam.AnnualSourceHeadSandbox.Selected := do
  requireOk (← Loam.AnnualSourceHeadSandbox.readSelected? root)
    "selected annual source cannot replay"

private def seed (root : System.FilePath)
    (beforeFile afterFile headPin imagePin : String) : IO Unit := do
  let before ← load beforeFile
  let after ← load afterFile
  Loam.AnnualSandboxDurabilityBarriers.markDisposableRoot root
  let barriers := Loam.AnnualSandboxDurabilityBarriers.barriers root
  let base ← requireOk
    (← Loam.AnnualSourceHeadSandbox.bootstrapWithBarriers?
      root "2026" before.wire barriers) "2026 baseline"
  expect (base.head.years.isEmpty &&
          !(← (root / "journal" / "2027").pathExists))
    "idle next year was provisioned without an admitted operation"
  let first ← requireOk
    (← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
      root base.headWire "2027-01-03" "scheduled-completion:first"
      ["Actual", "Scheduled"] after.image barriers)
    "2027 Actual+Scheduled first admission"
  expect (first.operations == ["scheduled-completion:first"] &&
          first.generation.wire == after.wire)
    "2027 admitted source diverged from canonical fixture"
  let nextImage ← withLoci after ["bank", "wifi", "other"]
  let next ← requireOk
    (← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
      root first.headWire "2028-01-01" "expand-vocabulary"
      ["LocusAdmission"] nextImage barriers)
    "2028 next-year native source"
  let current ← selected root
  expect (current.headWire == next.headWire &&
          current.generation.wire == next.generation.wire &&
          current.head.years == ["2027", "2028"] &&
          current.operations == ["scheduled-completion:first", "expand-vocabulary"])
    "2026-2028 source chain was not selected"
  -- The independent pins are a synthetic test oracle, NOT a trusted
  -- freshness anchor or a product backup format.
  IO.FS.writeFile (System.FilePath.mk headPin) current.headWire
  IO.FS.writeFile (System.FilePath.mk imagePin) current.generation.wire
  expect ((← IO.FS.readFile (System.FilePath.mk beforeFile)) == before.wire &&
          (← IO.FS.readFile (System.FilePath.mk afterFile)) == after.wire)
    "native input fixture mutated"
  IO.println "NATIVE_ANNUAL_COPY_SEED_PASS 2026 genesis, idle year absent, Jan3+2028 generations pinned"

private def verify (root : System.FilePath)
    (headPin imagePin : String) (pinned : Bool) : IO Unit := do
  let current ← selected root
  expect (current.head.years == ["2027", "2028"] ||
          (!pinned && current.head.years == ["2027"]))
    "selected restored source is not the expected period"
  if pinned then
    expect (current.headWire == (← IO.FS.readFile (System.FilePath.mk headPin)))
      "restored complete but stale valid-old HEAD differs from independent pin"
    expect (current.generation.wire ==
      (← IO.FS.readFile (System.FilePath.mk imagePin)))
      "restored generation not byte-exact to independently pinned native image"
    expect (current.operations ==
      ["scheduled-completion:first", "expand-vocabulary"])
      "selected operation identities changed in restored closure"
  IO.println "NATIVE_ANNUAL_RESTORE_REPLAY_PASS selected closure qualified"

private def continueAfterRestore (root : System.FilePath)
    (headPin imagePin : String) : IO Unit := do
  verify root headPin imagePin true
  let before ← selected root
  let image ← withLoci before.generation ["bank", "wifi", "other", "later"]
  let barriers := Loam.AnnualSandboxDurabilityBarriers.barriers root
  let next ← requireOk
    (← Loam.AnnualSourceHeadSandbox.appendWithBarriers?
      root before.headWire "2029-01-07" "post-restore-new-operation"
      ["LocusAdmission"] image barriers)
    "append after restoring pinned native annual source"
  expect (next.head.years == ["2027", "2028", "2029"] &&
          next.operations ==
            ["scheduled-completion:first", "expand-vocabulary",
             "post-restore-new-operation"] &&
          next.generation.wire != before.generation.wire)
    "restored source could not continue in 2029"
  let again ← selected root
  expect (again.generation.wire == next.generation.wire &&
          again.operations == next.operations)
    "continued year-source not replayable after restore"
  IO.println "NATIVE_ANNUAL_RESTORE_CONTINUE_PASS restored selected generation continued into 2029"

def run (args : List String) : IO Unit := do
  match args with
  | ["seed", root, before, after, headPin, imagePin] =>
      seed (System.FilePath.mk root) before after headPin imagePin
  | ["verify", root, headPin, imagePin] =>
      verify (System.FilePath.mk root) headPin imagePin true
  | ["unpinned", root, headPin, imagePin] =>
      verify (System.FilePath.mk root) headPin imagePin false
  | ["continue", root, headPin, imagePin] =>
      continueAfterRestore (System.FilePath.mk root) headPin imagePin
  | _ => throw (IO.userError
      "usage: seed ROOT BEFORE AFTER HEAD_PIN IMAGE_PIN | verify|unpinned|continue ROOT HEAD_PIN IMAGE_PIN")

end Loam.Tools.NativeAnnualCopyRestoreProbe

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeAnnualCopyRestoreProbe.run args
