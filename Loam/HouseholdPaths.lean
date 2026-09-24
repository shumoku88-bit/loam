namespace Loam.HouseholdPaths

set_option autoImplicit false

/-!
# Passive household filesystem layout

This module owns only the established physical spelling of one household's
canonical files and replaceable configuration files.

It performs no IO, admission, publication, recovery, caching, or authority
selection. Callers still decide which evidence is required and which
Review/Publisher boundary owns the operation.
-/

def configDir (root : System.FilePath) : System.FilePath :=
  root / "config"

def actual (root : System.FilePath) : System.FilePath :=
  root / "actual.loam"

def scheduled (root : System.FilePath) : System.FilePath :=
  root / "scheduled.loam"

def capacity (root : System.FilePath) : System.FilePath :=
  root / "capacity.loam"

def attention (root : System.FilePath) : System.FilePath :=
  root / "attention.loam"

def actualRouting (root : System.FilePath) : System.FilePath :=
  root / "actual-routing.loam"

def scheduledRouting (root : System.FilePath) : System.FilePath :=
  root / "scheduled-routing.loam"

def accountingRole (root : System.FilePath) : System.FilePath :=
  root / "accounting-role.loam"

def zeroOriginCoverage (root : System.FilePath) : System.FilePath :=
  root / "zero-origin-coverage.loam"

def openingSupport (root : System.FilePath) : System.FilePath :=
  root / "opening-support.loam"

def currentQuantityAnchor (root : System.FilePath) : System.FilePath :=
  root / "current-quantity-anchor.loam"

def boundaryPresets (root : System.FilePath) : System.FilePath :=
  configDir root / "boundary-presets.tsv"

def measurePresentation (root : System.FilePath) : System.FilePath :=
  configDir root / "measure-presentation.tsv"

def locusCatalog (root : System.FilePath) : System.FilePath :=
  configDir root / "locus-catalog.tsv"

def purposeCatalog (root : System.FilePath) : System.FilePath :=
  configDir root / "purpose-catalog.tsv"

def balanceView (root : System.FilePath) : System.FilePath :=
  configDir root / "balance-view.tsv"

def cycleFunding (root : System.FilePath) : System.FilePath :=
  configDir root / "cycle-funding.tsv"

def dailyPace (root : System.FilePath) : System.FilePath :=
  configDir root / "daily-pace.tsv"

def scheduledCoverage (root : System.FilePath) : System.FilePath :=
  configDir root / "scheduled-coverage.tsv"

end Loam.HouseholdPaths
