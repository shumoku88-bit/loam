import Loam.Tests.IncrementalCorrectedFrontier

namespace Loam.Tests.IncrementalDeltaCostProbe

open Loam.Core
open Loam.Tests.IncrementalDailyDelta
open Loam.Tests.IncrementalCorrectedFrontier

set_option autoImplicit false

/-!
Manual, research-only, paired cost probe over *two admitted* normalized Actual
images. This is not a new query, correction admission path, or production cache.

Benchmarked:
1. full re-selection and re-aggregation of the changed image;
2. current full-root comparison and then two-bucket delta;
3. arithmetic delta when the changed root/old and new contribution are known.

Image construction and semantic admission are measured separately, outside the
paired read timings. This experiment does not measure file decoding, publication,
crash recovery, or production TUI input latency.

The current oneRootReplacement? has a List.find? nested in a List.mapM; the
scanned path can therefore be quadratic. Max size is deliberately bounded.
-/

private def jpy : MeasureId := ⟨"jpy"⟩
private def foodCoordinate : EffectCoordinate := ⟨⟨"food"⟩, jpy⟩

private def requireSome {α : Type} (value : Option α) (why : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError why)

private def event? (index : Nat) (quanta : Int) : Option Event :=
  Event.ofEffects? ⟨s!"bench-{index}"⟩
    [Effect.ofAnonymousQuantity ⟨"bank"⟩ jpy (Quantity.ofQuanta (-quanta)),
     Effect.ofAnonymousQuantity ⟨"food"⟩ jpy (Quantity.ofQuanta quanta)]

private def admittedPair (n : Nat) :
    IO (Loam.Persistence.AdmittedActualImage ×
        Loam.Persistence.AdmittedActualImage) := do
  let initial ← (List.range n).mapM fun i =>
    requireSome (event? i 1) "synthetic Event construction refused"
  let replacement ← requireSome (event? n 2) "synthetic replacement refused"
  let oldMemory ← requireSome (EventMemory.ofEvents? initial)
    "old Event memory refused"
  let newMemory ← requireSome (EventMemory.ofEvents? (initial ++ [replacement]))
    "new Event memory refused"
  let baseDates := initial.map fun e =>
    ActualValidityFact.base e.id "2026-10-03"
  let oldDates ← requireSome
    (ActualValidityHistory.ofParts? baseDates [])
    "old occurrence dates refused"
  let newDates ← requireSome
    (ActualValidityHistory.ofParts?
      (baseDates ++ [.base replacement.id "2026-10-05"]) [])
    "new occurrence dates refused"
  let corrections ← requireSome
    (EventCorrectionMemory.ofCorrections?
      [{ target := ⟨s!"bench-{n - 1}"⟩, replacement := replacement.id }])
    "raw correction memory refused"
  let oldEvidence : Loam.ActualEvidence :=
    { Loam.ActualEvidence.empty with
      events := oldMemory, validity := oldDates }
  let newEvidence : Loam.ActualEvidence :=
    { Loam.ActualEvidence.empty with
      events := newMemory, validity := newDates, corrections := corrections }
  let oldImage ← requireSome (Loam.Persistence.admitActualImage? oldEvidence)
    "old normalized Actual admission refused"
  let newImage ← requireSome (Loam.Persistence.admitActualImage? newEvidence)
    "new normalized Actual admission refused"
  return (oldImage, newImage)

private def queriedBuckets : List Bucket :=
  [{ day := "2026-10-03", measure := "jpy" },
   { day := "2026-10-05", measure := "jpy" }]

/-- Full, qualified-image read path: no cache or delta assumption. -/
@[noinline] private def fullRecompute
    (image : Loam.Persistence.AdmittedActualImage) : Option (List Int) := do
  let rows ← selectedRows? foodCoordinate
    (Loam.ActualReview.recordsFromActualImage image)
  return queriedBuckets.map fun bucket => recompute bucket rows


/--
The simplest competing implementation: read the already-admitted CURRENT Event
projection once, for two explicit date/Measure buckets. The existing admission
boundary still owns correction selection and date validity.
No cached totals, root matching, or extra persistent facts.
-/
@[noinline] private def singlePassCurrentTotals
    (image : Loam.Persistence.AdmittedActualImage) : Option (List Int) := do
  let (first, second) ← image.currentEvents.events.foldlM
      (init := ((0 : Int), (0 : Int))) fun (first, second) event => do
    let quantity :=
      (Event.quantityAt event foodCoordinate.locus foodCoordinate.measure).quanta
    if quantity == 0 then
      return (first, second)
    let day ← image.currentValidities.findByEventId? event.id
    if day == "2026-10-03" then
      return (first + quantity, second)
    else if day == "2026-10-05" then
      return (first, second + quantity)
    else
      return (first, second)
  return [first, second]

/-- Count root equality checks performed by a linear List.find? lookup. -/
private def findComparisonCount (id : EventId)
    (rows : List (EventId × Option Contribution)) : Nat :=
  match rows with
  | [] => 0
  | row :: remaining =>
      if row.1 == id then 1 else 1 + findComparisonCount id remaining

/--
Deterministic algorithmic-cost witness. Each before-root triggers a search of
the new-root list. Unlike interpreter microtimings, counts cannot be distorted
by thunk sharing, clock resolution, CPU scheduling, or benchmark hoisting.
-/
private def discoveryComparisonCount
    (beforeImage afterImage : Loam.Persistence.AdmittedActualImage) :
    Option Nat := do
  let beforeRoots ← rootedRows? foodCoordinate beforeImage
  let afterRoots ← rootedRows? foodCoordinate afterImage
  if beforeRoots.length != afterRoots.length then
    none
  if !(beforeRoots.all fun (root, _) =>
      afterRoots.any fun (target, _) => target == root) then
    none
  return beforeRoots.foldl
    (fun count (root, _) => count + findComparisonCount root afterRoots) 0

/-- The currently implemented full-root comparison, with old totals supplied. -/
@[noinline] private def scannedDelta
    (beforeImage afterImage : Loam.Persistence.AdmittedActualImage)
    (oldTotals : List Int) : Option (List Int) := do
  let (removed, added) ←
    oneRootReplacement? foodCoordinate beforeImage afterImage
  return (queriedBuckets.zip oldTotals).map fun (bucket, oldTotal) =>
    afterReplacement bucket oldTotal removed added

/-- Lower-bound cost if an existing trusted operation already names its old/new contributions. -/
@[noinline] private def knownDelta
    (oldTotals : List Int) (removed added : Contribution) : List Int :=
  (queriedBuckets.zip oldTotals).map fun (bucket, oldTotal) =>
    afterReplacement bucket oldTotal removed added

/-- The measured action must provide the correct two results on every iteration. -/
private def medianNsPerCall (repetitions batchSize : Nat) (expected : List Int)
    (action : Unit → Option (List Int)) : IO Nat := do
  let mut times : Array Nat := #[]
  for _ in List.range repetitions do
    let t0 ← IO.monoNanosNow
    -- Force and compare every answer during the timed interval.
    for _ in List.range batchSize do
      let candidate := action ()
      unless candidate == some expected do
        throw (IO.userError "delta benchmark answer/refusal mismatch")
    let t1 ← IO.monoNanosNow
    times := times.push ((t1 - t0) / batchSize)
  let sorted := times.qsort (· < ·)
  return sorted[sorted.size / 2]!

private def runCase (n repetitions : Nat) : IO Unit := do
  let admissionStart ← IO.monoNanosNow
  let (oldImage, newImage) ← admittedPair n
  let admissionEnd ← IO.monoNanosNow
  let admissionUs := (admissionEnd - admissionStart) / 1000

  let oldTotals ← requireSome (fullRecompute oldImage)
    "old admitted image selection refused"
  let expected ← requireSome (fullRecompute newImage)
    "new admitted image selection refused"
  let removed : Contribution :=
    { bucket := { day := "2026-10-03", measure := "jpy" }, signedQuanta := 1 }
  let added : Contribution :=
    { bucket := { day := "2026-10-05", measure := "jpy" }, signedQuanta := 2 }
  unless singlePassCurrentTotals oldImage == some oldTotals do
    throw (IO.userError "single-pass old answer differs from full reader")
  unless singlePassCurrentTotals newImage == some expected do
    throw (IO.userError "single-pass new answer differs from full reader")
  let rootComparisons ← requireSome (discoveryComparisonCount oldImage newImage)
    "root discovery comparison count refused"
  -- Full old/new sets have exactly n stable roots, in any order, so repeated
  -- List.find? necessarily makes 1 + ... + n equality checks.
  let triangular := n * (n + 1) / 2
  unless rootComparisons == triangular do
    throw (IO.userError s!"unexpected root scan comparisons: {rootComparisons} vs {triangular}")
  unless newImage.currentEvents.events.length == n do
    throw (IO.userError "corrected current Event count differs from n")
  unless scannedDelta oldImage newImage oldTotals == some expected do
    throw (IO.userError "scanned candidate differs from full read")
  unless knownDelta oldTotals removed added == expected do
    throw (IO.userError "known change differs from full read")

  -- The same images/old totals are reused. Read time excludes building and
  -- qualifying them; it also excludes the initial oldTotal calculation.
  let batchSize := 10
  let fullNs ← medianNsPerCall repetitions batchSize expected fun _ =>
    fullRecompute newImage
  let simpleNs ← medianNsPerCall repetitions batchSize expected fun _ =>
    singlePassCurrentTotals newImage
  let scannedNs ← medianNsPerCall repetitions batchSize expected fun _ =>
    scannedDelta oldImage newImage oldTotals
  let knownNs ← medianNsPerCall repetitions batchSize expected fun _ =>
    some (knownDelta oldTotals removed added)
  IO.println s!"{n}\t{n}\t{rootComparisons}\t{admissionUs}\t{fullNs}\t{simpleNs}\t{scannedNs}\t{knownNs}\t{repr expected}"

def main (args : List String) : IO Unit := do
  let sizes ← if args.isEmpty then
    pure [100, 300, 600]
  else
    args.mapM fun arg =>
      match arg.toNat? with
      | some n => pure n
      | none => throw (IO.userError s!"invalid Event count: {arg}")
  for n in sizes do
    if n == 0 || n > 10000 then
      throw (IO.userError "Event count must be between 1 and 10,000; O(n²) scanned path is not qualified for larger sizes")
  let repetitions := 3
  IO.println "events\tcurrent_events\troot_lookup_comparisons\tadmit_pair_us\tfull_read_ns\tsimple_pass_ns\troot_scan_delta_ns\tknown_delta_ns\tnew_totals"
  for n in sizes do
    runCase n repetitions

end Loam.Tests.IncrementalDeltaCostProbe

-- Imported proof modules already own a root-level 'main'. Run this manual
-- research probe through evaluation, never by replacing their test entrance.
#eval (show IO Unit from do
  let configured ← IO.getEnv "LOAM_DELTA_BENCH_SIZES"
  let inputs := match configured with
    | some values => values.splitOn ","
    | none => ["40", "100", "200"]
  Loam.Tests.IncrementalDeltaCostProbe.main inputs
)
