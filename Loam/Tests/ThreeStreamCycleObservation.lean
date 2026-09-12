import Loam.CycleBudgetReview

set_option autoImplicit false

/--
Read-only, path-independent observation used by the three-stream compression
experiment. It intentionally calls the current production CycleBudgetReview
boundary rather than reconstructing CurrentCoverage arithmetic in the test.
-/
def main (args : List String) : IO Unit := do
  let [path, observedAt] := args
    | throw (IO.userError "usage: ThreeStreamCycleObservation DATA_DIR OBSERVED_AT")
  let dataDir := System.FilePath.mk path
  let snapshot ←
    Loam.CycleBudgetReview.loadSnapshotAt
      dataDir (dataDir / "movement-authority") observedAt

  let .ok window := snapshot.window
    | throw (IO.userError s!"window unavailable: {repr snapshot.window}")
  let .ok coverage := snapshot.coverage
    | throw (IO.userError s!"coverage unavailable: {repr snapshot.coverage}")
  let .ok physical := snapshot.physical
    | throw (IO.userError s!"physical unavailable: {repr snapshot.physical}")
  let .ok selection := snapshot.selection
    | throw (IO.userError s!"funding selection unavailable: {repr snapshot.selection}")
  let .ok funding := snapshot.funding
    | throw (IO.userError s!"funding unavailable: {repr snapshot.funding}")

  -- Repr is deterministic for these retained ordered structures and deliberately
  -- excludes filesystem paths. A byte diff therefore compares the current
  -- production answer, not the storage location used to obtain it.
  IO.println s!"observedAt\t{snapshot.observedAt}"
  IO.println s!"window\t{repr window}"
  IO.println s!"coverage\t{repr coverage}"
  IO.println s!"physical\t{repr physical}"
  IO.println s!"selection\t{repr selection}"
  IO.println s!"funding\t{repr funding}"
