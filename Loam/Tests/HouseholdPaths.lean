import Loam.HouseholdPaths

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def expectPath
    (actual expected : System.FilePath)
    (label : String) : IO Unit :=
  expect (actual == expected) ("unexpected household path for " ++ label)

def main : IO Unit := do
  let root := System.FilePath.mk "/tmp/loam-household-paths"

  expectPath (Loam.HouseholdPaths.actual root)
    (System.FilePath.mk "/tmp/loam-household-paths/actual.loam") "Actual"
  expect (Loam.HouseholdPaths.actualFileName == "actual.loam")
    "unexpected Actual filename identity"
  expectPath (Loam.HouseholdPaths.scheduled root)
    (System.FilePath.mk "/tmp/loam-household-paths/scheduled.loam") "Scheduled"
  expectPath (Loam.HouseholdPaths.capacity root)
    (System.FilePath.mk "/tmp/loam-household-paths/capacity.loam") "Capacity"
  expectPath (Loam.HouseholdPaths.attention root)
    (System.FilePath.mk "/tmp/loam-household-paths/attention.loam") "Attention"
  expectPath (Loam.HouseholdPaths.actualRouting root)
    (System.FilePath.mk "/tmp/loam-household-paths/actual-routing.loam") "Actual routing"
  expectPath (Loam.HouseholdPaths.scheduledRouting root)
    (System.FilePath.mk "/tmp/loam-household-paths/scheduled-routing.loam") "Scheduled routing"
  expectPath (Loam.HouseholdPaths.accountingRole root)
    (System.FilePath.mk "/tmp/loam-household-paths/accounting-role.loam") "AccountingRole"
  expectPath (Loam.HouseholdPaths.locusAdmission root)
    (System.FilePath.mk "/tmp/loam-household-paths/locus-admission.loam") "Locus admission"
  expect (Loam.HouseholdPaths.locusAdmissionFileName == "locus-admission.loam")
    "unexpected Locus admission filename identity"
  expectPath (Loam.HouseholdPaths.zeroOriginCoverage root)
    (System.FilePath.mk "/tmp/loam-household-paths/zero-origin-coverage.loam") "zero-origin coverage"
  expectPath (Loam.HouseholdPaths.openingSupport root)
    (System.FilePath.mk "/tmp/loam-household-paths/opening-support.loam") "opening support"
  expectPath (Loam.HouseholdPaths.currentQuantityAnchor root)
    (System.FilePath.mk "/tmp/loam-household-paths/current-quantity-anchor.loam") "current quantity anchor"
  expect (Loam.HouseholdPaths.currentQuantityAnchorFileName == "current-quantity-anchor.loam")
    "unexpected CurrentQuantityAnchor filename identity"
  expectPath (Loam.HouseholdPaths.currentQuantityPresence root)
    (System.FilePath.mk "/tmp/loam-household-paths/current-quantity-presence.loam") "current quantity presence"
  expect (Loam.HouseholdPaths.currentQuantityPresenceFileName == "current-quantity-presence.loam")
    "unexpected CurrentQuantityPresence filename identity"

  expectPath (Loam.HouseholdPaths.boundaryPresets root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/boundary-presets.tsv") "boundary presets"
  expectPath (Loam.HouseholdPaths.measurePresentation root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/measure-presentation.tsv") "measure presentation"
  expect (Loam.HouseholdPaths.measurePresentationFileName == "measure-presentation.tsv")
    "unexpected Measure presentation filename identity"
  expectPath (Loam.HouseholdPaths.locusCatalog root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/locus-catalog.tsv") "Locus catalog"
  expectPath (Loam.HouseholdPaths.purposeCatalog root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/purpose-catalog.tsv") "Purpose catalog"
  expectPath (Loam.HouseholdPaths.balanceView root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/balance-view.tsv") "balance view"
  expectPath (Loam.HouseholdPaths.cycleFunding root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/cycle-funding.tsv") "cycle funding"
  expectPath (Loam.HouseholdPaths.dailyPace root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/daily-pace.tsv") "daily pace"
  expectPath (Loam.HouseholdPaths.scheduledCoverage root)
    (System.FilePath.mk "/tmp/loam-household-paths/config/scheduled-coverage.tsv") "Scheduled coverage"

  IO.println "HouseholdPaths: canonical and config path composition passed."
