import Loam.Migration.HouseholdImageInstall

namespace Loam.HouseholdImageInstallCli

set_option autoImplicit false

private def usage : String :=
  "Usage: loam household-image install-initial LEGACY_ROOT SCRATCH_ROOT " ++
  "WINDOW_START OBSERVED_AT END_EXCLUSIVE"

def run (args : List String) : IO UInt32 := do
  let [legacyText, scratchText, windowStart, observedAt, endExclusive] := args
    | IO.eprintln usage
      return 2

  if legacyText.isEmpty || scratchText.isEmpty then
    IO.eprintln "loam: legacy and scratch directories must not be empty"
    return 2

  let root := System.FilePath.mk legacyText
  let probe : Loam.HouseholdImageDryRun.ReviewProbe := {
    currentWindowStart := windowStart
    observedAt := observedAt
    endExclusive := endExclusive
  }

  match ←
      Loam.HouseholdImageInstall.run
        root
        (System.FilePath.mk scratchText)
        probe with
  | .error message =>
      IO.eprintln "HouseholdImage initial install: refused"
      IO.eprintln message
      return 2
  | .ok report =>
      IO.println "HouseholdImage initial install: complete"
      IO.println ("authority: " ++ (Loam.HouseholdAuthority.path root).toString)
      IO.println ("qualified candidate: " ++ report.dryRun.candidatePath.toString)
      IO.println "legacy authorities retained: yes"
      IO.println "previous HouseholdImage generation: none (initial install)"
      IO.println "production read/write cutover: not performed"
      return 0

end Loam.HouseholdImageInstallCli
