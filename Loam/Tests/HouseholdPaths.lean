import Loam.HouseholdPaths

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def pathText (path : System.FilePath) : String :=
  path.toString

def main : IO Unit := do
  let root := System.FilePath.mk "/household"

  let exact : List (String × System.FilePath) := [
    ("/household/actual.loam", Loam.HouseholdPaths.actual root),
    ("/household/scheduled.loam", Loam.HouseholdPaths.scheduled root),
    ("/household/capacity.loam", Loam.HouseholdPaths.capacity root),
    ("/household/attention.loam", Loam.HouseholdPaths.attention root),
    ("/household/actual-routing.loam", Loam.HouseholdPaths.actualRouting root),
    ("/household/scheduled-routing.loam", Loam.HouseholdPaths.scheduledRouting root),
    ("/household/accounting-role.loam", Loam.HouseholdPaths.accountingRole root),
    ("/household/locus-admission.loam", Loam.HouseholdPaths.locusAdmission root),
    ("/household/zero-origin-coverage.loam", Loam.HouseholdPaths.zeroOriginCoverage root),
    ("/household/opening-support.loam", Loam.HouseholdPaths.openingSupport root),
    ("/household/current-quantity-anchor.loam", Loam.HouseholdPaths.currentQuantityAnchor root),
    ("/household/config/boundary-presets.tsv", Loam.HouseholdPaths.boundaryPresets root),
    ("/household/config/measure-presentation.tsv", Loam.HouseholdPaths.measurePresentation root),
    ("/household/config/locus-catalog.tsv", Loam.HouseholdPaths.locusCatalog root),
    ("/household/config/purpose-catalog.tsv", Loam.HouseholdPaths.purposeCatalog root),
    ("/household/config/balance-view.tsv", Loam.HouseholdPaths.balanceView root),
    ("/household/config/cycle-funding.tsv", Loam.HouseholdPaths.cycleFunding root),
    ("/household/config/daily-pace.tsv", Loam.HouseholdPaths.dailyPace root),
    ("/household/config/scheduled-coverage.tsv", Loam.HouseholdPaths.scheduledCoverage root)
  ]

  for (expected, actual) in exact do
    expect (pathText actual == expected)
      ("household path mismatch: expected " ++ expected ++ ", got " ++ pathText actual)

  expect (Loam.HouseholdPaths.actualFileName == "actual.loam")
    "Actual filename changed"
  expect (Loam.HouseholdPaths.configDirName == "config")
    "config directory name changed"

  IO.println "HouseholdPaths: passive canonical/config path composition passed."
