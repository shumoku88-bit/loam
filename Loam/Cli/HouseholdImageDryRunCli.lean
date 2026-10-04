import Loam.Migration.HouseholdImageDryRun

namespace Loam.HouseholdImageDryRunCli

set_option autoImplicit false

private def usage : String :=
  "Usage: loam household-image dry-run LEGACY_ROOT SCRATCH_ROOT " ++
  "WINDOW_START OBSERVED_AT END_EXCLUSIVE"

private def sectionList (sections : List String) : String :=
  if sections.isEmpty then "(none)" else String.intercalate ", " sections

def run (args : List String) : IO UInt32 := do
  let [legacyText, scratchText, windowStart, observedAt, endExclusive] := args
    | IO.eprintln usage
      return 2

  if legacyText.isEmpty || scratchText.isEmpty then
    IO.eprintln "loam: legacy and scratch directories must not be empty"
    return 2

  let probe : Loam.HouseholdImageDryRun.ReviewProbe := {
    currentWindowStart := windowStart
    observedAt := observedAt
    endExclusive := endExclusive
  }

  match ←
      Loam.HouseholdImageDryRun.run
        (System.FilePath.mk legacyText)
        (System.FilePath.mk scratchText)
        probe with
  | .error message =>
      IO.eprintln "HouseholdImage dry-run: migration refused"
      IO.eprintln message
      return 2
  | .ok report =>
      IO.println "HouseholdImage dry-run: migration possible"
      IO.println ("candidate: " ++ report.candidatePath.toString)
      IO.println ("projection: " ++ report.projectionRoot.toString)
      IO.println ("present sections: " ++ sectionList report.presentSections)
      IO.println ("absent sections: " ++ sectionList report.absentSections)
      IO.println "authority unchanged: household.loam was not installed"
      return 0

end Loam.HouseholdImageDryRunCli
