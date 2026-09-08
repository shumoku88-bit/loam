import Loam.CurrentCoverageReview

open Loam.Core

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some result => pure result
  | none => throw (IO.userError message)

private structure ExpectedRow where
  purpose : String
  entitlement : Int
  remaining : Int
  headroom : Int

private def expectedRows : List ExpectedRow :=
  [ { purpose := "食費", entitlement := 39000, remaining := 20328, headroom := 20328 }
  , { purpose := "食費:ストック", entitlement := 7000, remaining := -1180, headroom := -1180 }
  , { purpose := "一般生活", entitlement := 22346, remaining := -5546, headroom := -5546 }
  , { purpose := "タバコ", entitlement := 29500, remaining := 16500, headroom := 16500 }
  , { purpose := "固定費予定", entitlement := 17108, remaining := 8730, headroom := 982 }
  , { purpose := "通院", entitlement := 2000, remaining := 1510, headroom := 1510 }
  ]

private def findRow?
    (snapshot : Loam.CurrentCoverageReview.Snapshot)
    (purpose : String) : Option Loam.CurrentCoverageReview.Row :=
  snapshot.rows.find? fun row => row.purpose.token == purpose

/--
Explicit 2026-09-08 real-data dogfood checkpoint for the reconciled current
window beginning 2026-08-14. This is intentionally run against a separately
checked-out `loam-data`; it is not synthetic CI authority and does not make LOAM
operational household authority. Boundary-preset configuration is checked
separately rather than silently changed by this projection regression.
-/
def main (args : List String) : IO Unit := do
  let [dataPath] := args
    | throw (IO.userError "usage: CurrentCoverageDogfood DATA_DIR")
  let dataDir := System.FilePath.mk dataPath
  let .ok snapshot ← Loam.CurrentCoverageReview.loadSnapshotAt
      dataDir (dataDir / "movement-authority")
      "2026-08-14" "2026-09-08" "2026-10-15"
    | throw (IO.userError "current real-data coverage projection was unavailable")

  for expected in expectedRows do
    let row ← requireSome (findRow? snapshot expected.purpose)
      s!"missing dogfood Purpose {expected.purpose}"
    expect (row.entitlement.quanta == expected.entitlement)
      s!"{expected.purpose}: Entitlement changed to {row.entitlement.quanta}"
    expect (row.remaining.quanta == expected.remaining)
      s!"{expected.purpose}: current Remaining changed to {row.remaining.quanta}"
    expect (row.headroom.quanta == expected.headroom)
      s!"{expected.purpose}: after-known Headroom changed to {row.headroom.quanta}"

  let fixed ← requireSome (findRow? snapshot "固定費予定") "missing fixed-cost row"
  expect (fixed.commitment.quanta == 7748)
    s!"fixed-cost managed Commitment changed to {fixed.commitment.quanta}"
  let frontier ← requireSome snapshot.scheduledFrontier "missing Scheduled frontier"
  expect (frontier.unresolvedEligibility.quanta == 4810)
    s!"unresolved future pressure changed to {frontier.unresolvedEligibility.quanta}"
  expect (frontier.unmanaged.quanta == 0) "invented unmanaged future pressure"
  expect (frontier.unrouted.quanta == 0) "invented unrouted future pressure"

  IO.println "Current Coverage real-data checkpoint: elapsed Actual window and future Scheduled pressure passed."
