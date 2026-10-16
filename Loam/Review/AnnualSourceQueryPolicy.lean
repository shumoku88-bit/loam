import Loam.Review.AnnualSourceReadView
import Loam.Config.DailyPaceConfig
import Loam.Config.BoundaryPresetConfig

namespace Loam.AnnualSourceQueryPolicy

open Loam.Core

set_option autoImplicit false

/-!
# Explicit exact-byte current query policy for a source-pinned annual read

The current Daily Pace pool and pension-cycle presets live in replaceable
TSV configuration, NOT in the canonical HouseholdImage or annual source journal.
This module fixes their exact supplied bytes for ONE current-truth query and
reuses the production decoders/projections. It does not invent policy history,
a publication timestamp, an atomically captured multi-file filesystem view,
or "as known on this day" answers.

The caller must supply a qualifying pair of query config contents. A separate
future protocol must coordinate configuration adoption with semantic source
publication before any historical learned-time interpretation is allowed.
-/

/-- Immutable value pairing exact, caller-provided current query bytes with the
typed selection and uniquely admitted calendar window. The raw contents are
kept specifically so a later comparison never confuses equal-looking decoded
queries with the same external policy version. -/
structure Policy where
  measure : MeasureId
  observedAt : String
  poolWire : String
  boundaryWire : String
  selection : List EffectCoordinate
  window : Loam.BoundaryPresetConfig.CurrentWindow

/-- Qualify both replaceable config bodies together as one explicit query
selection. An empty pool, malformed content, wrong Measure, absent cycle, or
ambiguous overlapping cycle presets is unavailable, not a zero Daily Pace. -/
def admit?
    (measure : MeasureId)
    (observedAt poolWire boundaryWire : String) :
    Except String Policy := do
  let some selection := Loam.DailyPaceConfig.decodeForMeasure? measure poolWire
    | throw "loam: annual Daily Pace pool policy missing or invalid"
  if selection.isEmpty then
    throw "loam: annual Daily Pace needs an explicit nonempty pool"
  let some presets := Loam.BoundaryPresetConfig.decode? boundaryWire
    | throw "loam: annual Daily Pace boundary policy missing or invalid"
  let window ← Loam.BoundaryPresetConfig.currentWindowFor? presets observedAt
  return {
    measure
    observedAt
    poolWire
    boundaryWire
    selection
    window
  }

/-- Require byte-exact identity to an already-captured query policy. This
alone never proves a filesystem writer did not change-and-restore content;
only explicit supplied versions, not temporal history, are compared. -/
def Policy.requireSameBytes?
    (policy : Policy)
    (poolWire boundaryWire : String) : Except String Unit :=
  if policy.poolWire == poolWire && policy.boundaryWire == boundaryWire then
    .ok ()
  else
    .error "loam: Daily Pace query policy changed since captured selection"

/-- Current-truth Daily Pace from ONE native annual read generation and ONE
explicit pinned query selection. Neither the year-source label nor Jan 1
determines the pension-cycle start/end. -/
def Policy.project?
    (policy : Policy)
    (view : Loam.AnnualSourceReadView.Snapshot) :
    Except String Loam.CycleSpendingPaceReview.Snapshot :=
  view.paceForMeasure?
    policy.measure policy.observedAt policy.window.endExclusive policy.selection

end Loam.AnnualSourceQueryPolicy
