import Loam.Authority.HouseholdAuthority
import Loam.Tests.Support

namespace Loam.Tools.BenchHouseholdKnowledge

open Loam.Persistence.HouseholdImage
open Loam.Tests.Support

set_option autoImplicit false

private def elapsedUs (before after : UInt64) : Nat :=
  (after - before).toNat / 1000

def mainRun (args : List String) : IO Unit := do
  let [rootText, seedText, nextText, roundsText] := args
    | throw (IO.userError "usage: BenchHouseholdKnowledge ROOT SEED NEXT_ACTUAL READ_ROUNDS")
  let some rounds := roundsText.toNat?
    | throw (IO.userError "invalid read rounds")
  if rounds == 0 then throw (IO.userError "read rounds must be nonzero")
  let root := System.FilePath.mk rootText
  if ← root.pathExists then IO.FS.removeDirAll root
  IO.FS.createDirAll root
  let seed ← IO.FS.readFile (System.FilePath.mk seedText)
  let nextBody ← IO.FS.readFile (System.FilePath.mk nextText)
  let source ← requireSome (decode? seed) "outer Household fixture decode"
  let startInstall ← IO.monoNanosNow
  let installed ← requireOk (← Loam.HouseholdAuthority.installInitial? root source)
    "qualified install"
  let endInstall ← IO.monoNanosNow
  expect (installed.wire == seed) "qualified install changed candidate bytes"
  let mut readTotal : Nat := 0
  for _ in [:rounds] do
    let before ← IO.monoNanosNow
    let current ← requireOk (← Loam.HouseholdAuthority.loadCurrent? root)
      "qualified load"
    let after ← IO.monoNanosNow
    readTotal := readTotal + elapsedUs before after
    expect (current.wire == seed) "read changed source generation"
  let candidate ← requireSome
    (replaceBody? installed.image "Actual" nextBody)
    "replace Actual"
  -- A production publisher must not rewrite a future unknown section.
  let tampered ← requireSome
    (replaceBody? candidate "ResearchKnowledge" "corrupted")
    "tamper unknown section"
  match ← Loam.HouseholdAuthority.publishObserved? root installed.wire ["Actual"] tampered with
  | .ok _ => throw (IO.userError "unknown research section mutated through Actual writer")
  | .error _ => pure ()
  let unchanged ← requireOk (← Loam.HouseholdAuthority.loadCurrent? root)
    "load after refused unknown mutation"
  expect (unchanged.wire == seed) "refusal affected HouseholdImage"
  let beforePublish ← IO.monoNanosNow
  let written ← requireOk
    (← Loam.HouseholdAuthority.publishObserved? root installed.wire ["Actual"] candidate)
    "qualified Household Actual publication"
  let afterPublish ← IO.monoNanosNow
  expect (body? written.image "ResearchKnowledge" == body? installed.image "ResearchKnowledge")
    "unknown section not preserved"
  let beforeAfterRead ← IO.monoNanosNow
  let qualifiedAfter ← requireOk (← Loam.HouseholdAuthority.loadCurrent? root)
    "qualified load after publication"
  let afterAfterRead ← IO.monoNanosNow
  expect (qualifiedAfter.wire == written.wire) "post-publication read differs"
  match ← Loam.HouseholdAuthority.publishObserved? root installed.wire ["Actual"] candidate with
  | .ok _ => throw (IO.userError "stale observed generation accepted")
  | .error _ => pure ()
  let previous ← IO.FS.readFile (Loam.HouseholdAuthority.previousPath root)
  expect (previous == seed) "previous HouseholdImage not preserved"
  let finalWire ← IO.FS.readFile (Loam.HouseholdAuthority.path root)
  expect (finalWire == written.wire) "final authority file does not match qualified read"
  IO.println s!"BENCH\tqualified\t{seed.utf8ByteSize}\t{finalWire.utf8ByteSize}\t{previous.utf8ByteSize}\t{elapsedUs startInstall endInstall}\t{readTotal / rounds}\t{elapsedUs beforePublish afterPublish}\t{elapsedUs beforeAfterRead afterAfterRead}"

end Loam.Tools.BenchHouseholdKnowledge

def main (args : List String) : IO Unit :=
  Loam.Tools.BenchHouseholdKnowledge.mainRun args
