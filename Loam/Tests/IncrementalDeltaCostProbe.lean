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
private def medianUs (repetitions : Nat) (expected : List Int)
    (action : Unit → Option (List Int)) : IO Nat := do
  let mut times : Array Nat := #[]
  for _ in List.range repetitions do
    let t0 ← IO.monoNanosNow
    let candidate := action ()
    let t1 ← IO.monoNanosNow
    unless candidate == some expected do
      throw (IO.userError "delta benchmark answer/refusal mismatch")
    times := times.push ((t1 - t0) / 1000)
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
  unless scannedDelta oldImage newImage oldTotals == some expected do
    throw (IO.userError "scanned candidate differs from full read")
  unless knownDelta oldTotals removed added == expected do
    throw (IO.userError "known change differs from full read")

  -- The same images/old totals are reused. Read time excludes building and
  -- qualifying them; it also excludes the initial oldTotal calculation.
  let fullUs ← medianUs repetitions expected fun _ =>
    fullRecompute newImage
  let scannedUs ← medianUs repetitions expected fun _ =>
    scannedDelta oldImage newImage oldTotals
  let knownUs ← medianUs repetitions expected fun _ =>
    some (knownDelta oldTotals removed added)
  IO.println s!"{n}\t{admissionUs}\t{fullUs}\t{scannedUs}\t{knownUs}\t{repr expected}"

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
  IO.println "events\tadmit_pair_us\tfull_read_us\troot_scan_delta_us\tknown_delta_us\tnew_totals"
  for n in sizes do
    runCase n repetitions

end Loam.Tests.IncrementalDeltaCostProbe

-- Imported proof modules already own a root-level 'main'. Run this manual
-- research probe through evaluation, never by replacing their test entrance.
#eval do
  let configured ← IO.getEnv "LOAM_DELTA_BENCH_SIZES"
  let inputs := match configured with
    | some values => values.splitOn ","
    | none => ["40", "100", "200"]
  Loam.Tests.IncrementalDeltaCostProbe.main inputs
