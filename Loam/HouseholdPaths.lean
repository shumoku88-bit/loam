import Std

namespace Loam.HouseholdPaths

set_option autoImplicit false

/-!
# Household filesystem topology

This module is the passive vocabulary for one household root's established
physical layout.

It owns path spelling only. It performs no I/O, loading, validation, admission,
publication, locking, caching, recovery, or semantic selection. Those
responsibilities remain with the existing Authority, Review, Publisher, and
persistence boundaries.
-/

def configDirName : String := "config"

def actualFileName : String := "actual.loam"
def scheduledFileName : String := "scheduled.loam"
def capacityFileName : String := "capacity.loam"
def attentionFileName : String := "attention.loam"
def actualRoutingFileName : String := "actual-routing.loam"
def scheduledRoutingFileName : String := "scheduled-routing.loam"
def accountingRoleFileName : String := "accounting-role.loam"
def locusAdmissionFileName : String := "locus-admission.loam"
def zeroOriginCoverageFileName : String := "zero-origin-coverage.loam"
def openingSupportFileName : String := "opening-support.loam"
def currentQuantityAnchorFileName : String := "current-quantity-anchor.loam"

def boundaryPresetsFileName : String := "boundary-presets.tsv"
def measurePresentationFileName : String := "measure-presentation.tsv"
def locusCatalogFileName : String := "locus-catalog.tsv"
def purposeCatalogFileName : String := "purpose-catalog.tsv"
def balanceViewFileName : String := "balance-view.tsv"
def cycleFundingFileName : String := "cycle-funding.tsv"
def dailyPaceFileName : String := "daily-pace.tsv"
def scheduledCoverageFileName : String := "scheduled-coverage.tsv"

def configDir (root : System.FilePath) : System.FilePath :=
  root / configDirName

def actual (root : System.FilePath) : System.FilePath :=
  root / actualFileName

def scheduled (root : System.FilePath) : System.FilePath :=
  root / scheduledFileName

def capacity (root : System.FilePath) : System.FilePath :=
  root / capacityFileName

def attention (root : System.FilePath) : System.FilePath :=
  root / attentionFileName

def actualRouting (root : System.FilePath) : System.FilePath :=
  root / actualRoutingFileName

def scheduledRouting (root : System.FilePath) : System.FilePath :=
  root / scheduledRoutingFileName

def accountingRole (root : System.FilePath) : System.FilePath :=
  root / accountingRoleFileName

def locusAdmission (root : System.FilePath) : System.FilePath :=
  root / locusAdmissionFileName

def zeroOriginCoverage (root : System.FilePath) : System.FilePath :=
  root / zeroOriginCoverageFileName

def openingSupport (root : System.FilePath) : System.FilePath :=
  root / openingSupportFileName

def currentQuantityAnchor (root : System.FilePath) : System.FilePath :=
  root / currentQuantityAnchorFileName

def boundaryPresets (root : System.FilePath) : System.FilePath :=
  configDir root / boundaryPresetsFileName

def measurePresentation (root : System.FilePath) : System.FilePath :=
  configDir root / measurePresentationFileName

def locusCatalog (root : System.FilePath) : System.FilePath :=
  configDir root / locusCatalogFileName

def purposeCatalog (root : System.FilePath) : System.FilePath :=
  configDir root / purposeCatalogFileName

def balanceView (root : System.FilePath) : System.FilePath :=
  configDir root / balanceViewFileName

def cycleFunding (root : System.FilePath) : System.FilePath :=
  configDir root / cycleFundingFileName

def dailyPace (root : System.FilePath) : System.FilePath :=
  configDir root / dailyPaceFileName

def scheduledCoverage (root : System.FilePath) : System.FilePath :=
  configDir root / scheduledCoverageFileName

end Loam.HouseholdPaths
