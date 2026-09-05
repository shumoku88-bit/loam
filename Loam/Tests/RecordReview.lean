import Loam.Cli.ReviewCli

open Loam.Core Loam.ReviewCli

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw <| IO.userError message

private def record (id : String) (date : Option String) (description : String) : IO Record := do
  let some event := Event.ofEffects? ⟨id⟩ [
      Effect.ofQuantity ⟨"from"⟩ ⟨"wallet"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta (-1200)),
      Effect.ofQuantity ⟨"to"⟩ ⟨"food"⟩ ⟨"jpy"⟩ (Quantity.ofQuanta 1200)]
    | throw <| IO.userError "fixture admission failed"
  return { event, date, description, replacement := none }

def main : IO Unit := do
  let shifts := [
    ("2024-03-01", -1, some "2024-02-29"),
    ("2026-03-01", -1, some "2026-02-28"),
    ("2000-02-28", 1, some "2000-02-29"),
    ("1900-02-28", 1, some "1900-03-01"),
    ("2026-01-01", -7, some "2025-12-25"),
    ("2026-12-31", 7, some "2027-01-07"),
    ("0001-01-01", -1, none),
    ("9999-12-31", 1, none),
    ("2026-02-29", 0, none)]
  for (date, offset, expected) in shifts do
    expect (Loam.ActualDate.shiftDays? date offset == expected) ("day shift: " ++ date)
  expect (weekDays "0001-01-03" == ["0001-01-01", "0001-01-02", "0001-01-03"])
    "week must not invent out-of-range dates"
  expect (weekDays "2024-03-02" ==
    ["2024-02-25", "2024-02-26", "2024-02-27", "2024-02-28", "2024-02-29", "2024-03-01", "2024-03-02"])
    "week must cross leap month correctly"
  let a ← record "a" (some "2026-09-02") "スーパー Coffee"
  let z ← record "z" (some "2026-09-02") "same day"
  let old ← record "old" (some "2001-01-01") "old receipt"
  let unknown ← record "unknown" none "forgotten date"
  let corrected : Record := { a with replacement := some ⟨"z"⟩, isCurrent := false }
  let records := [unknown, old, z, a]
  let ids := fun rows : List Record => rows.map (·.event.id.token)
  expect (ids (select records (.week "2026-09-03")) == ["a", "z"])
    "recent window must use dates and deterministic ID ties"
  expect (ids (select records.reverse (.week "2026-09-03")) == ["a", "z"])
    "representation order must not become time"
  expect (ids (select [corrected, z] (.day "2026-09-02")) == ["z"])
    "daily review must not double-display a corrected record"
  expect (ids (select [corrected, z] (.search "スーパー")) == ["a"])
    "search must retain the original's recognition text without inheriting it"
  expect (ids (select records .undated) == ["unknown"])
    "undated evidence must be discoverable"
  for term in ["coffee", "COFFEE", "スーパー", "wallet", "jpy", "1200", "-1200"] do
    expect (containsText term a) ("search failed: " ++ term)
  expect (!containsText ".*" a) "search must be literal, not a regex language"
  expect (ids (select records (.search "receipt")) == ["old"])
    "search must not be confined to the current date window"
  expect (ids (select records (.search "forgotten")) == ["unknown"])
    "search must include undated evidence"
  let long : Record := { a with description := String.ofList (List.replicate 100 '長') ++ "needle" }
  expect (containsText "needle" long) "search must not use clipped presentation text"
  expect (!(summary long).contains '\n' && (summary long).length < 160)
    "long descriptions must not flood the summary"
  expect (displayText "a\nb\tc\x1b[2J" == "a\\nb\\tc�[2J")
    "presentation must not execute terminal controls"
  expect (parseQuery "2026-09-03" "/" == none) "empty search should be refused"
  expect (parseQuery "2026-09-03" "2026-02-29" == none) "invalid date should be refused"
  expect (parseQuery "2026-09-03" "t" == some (.week "2026-09-03"))
    "default recent window must be explicit"
  IO.println "Record review projection and calendar checks passed."
