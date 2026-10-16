import Loam.HouseholdPaths
import Loam.ActualDate
import Loam.Authority.ActualAuthority
import Loam.Review.ActualJournalProjection
import Loam.Persistence.TextEscape

namespace Loam.YearCli

open Loam.Core

set_option autoImplicit false

/-!
Read current-effective dated Actual records for one chosen calendar year.
The ordinary installed HouseholdImage remains the source until a separate
journal/YYYY/household.loam exists. This command never publishes or creates
household facts; an older saved generation need not know later corrections.
-/

def validYear (year : String) : Bool :=
  year.length == 4 && year.toNat?.isSome && year != "0000"

structure Report where
  sourceRoot : System.FilePath
  entries : List Loam.ActualJournalProjection.Entry

def readYear (root : System.FilePath) (year : String) :
    IO (Except String Report) := do
  if !validYear year then
    return .error "loam: year must be a four-digit calendar year (YYYY)"
  let archiveRoot := Loam.HouseholdPaths.yearRoot root year
  let archivePresent ← archiveRoot.pathExists
  -- A selected but incomplete older book must never silently resolve to
  -- the current book, which might report a misleading empty history.
  if archivePresent && !(← (Loam.HouseholdAuthority.path archiveRoot).pathExists) then
    return .error s!"loam: saved year {year} exists but its household.loam is missing"
  let sourceRoot := if archivePresent then archiveRoot else root
  let actual ←
    match ← Loam.ActualAuthority.loadHouseholdImage? sourceRoot with
    | .ok image => pure image
    | .error message => return .error message
  let entries ←
    match Loam.ActualJournalProjection.fromImage? actual with
    | .ok rows => pure rows
    | .error message => return .error message
  let dated := entries.filter fun entry => entry.validOn.startsWith (year ++ "-")
  if !archivePresent && dated.isEmpty then
    -- Legacy single-file households have no declared start year. The
    -- currently observed year may legitimately be empty, but an arbitrary
    -- older/future year with no dated evidence is unavailable, NOT zero.
    let observedDay? ← Loam.ActualDate.todayIso?
    if !(observedDay?.any fun day => day.startsWith (year ++ "-")) then
      return .error s!"loam: year {year} has no saved source or recorded Actual"
  return .ok {
    sourceRoot := sourceRoot
    entries := dated
  }

private def effectLine (effect : Effect) : String :=
  "  " ++ effect.coordinate.locus.token ++
  "\t" ++ toString effect.quantity.quanta ++
  "\t" ++ effect.coordinate.measure.token

private def entryLines (entry : Loam.ActualJournalProjection.Entry) : List String :=
  let heading := entry.validOn ++ "\t" ++ entry.event.id.token ++
    match entry.description with
    | some description => "\t" ++ Loam.Persistence.escapeText description
    | none => ""
  heading :: entry.event.effects.map effectLine

def render (year : String) (report : Report) : String :=
  String.intercalate "\n" <|
    [ "LOAM / " ++ year ++ " Actual (read-only)"
    , "Source: " ++ (Loam.HouseholdAuthority.path report.sourceRoot).toString
    , "Current-effective dated records in selected source: " ++
        toString report.entries.length
    , "Older saved sources may not contain corrections admitted later."
    , ""
    ] ++ report.entries.flatMap entryLines

private def resolveRoot (path? : Option String) :
    IO (Except String System.FilePath) := do
  match path? with
  | some path =>
      if path.isEmpty then return .error "loam: household root must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")

def run (args : List String) : IO UInt32 := do
  let (year, root?) ←
    match args with
    | [year] => pure (year, none)
    | [year, root] => pure (year, some root)
    | _ =>
        IO.eprintln "Usage: loam year YYYY [LOAM_DATA_DIR]"
        return 2
  let root ←
    match ← resolveRoot root? with
    | .ok root => pure root
    | .error message => IO.eprintln message; return 2
  match ← readYear root year with
  | .ok report =>
      IO.println (render year report)
      return 0
  | .error message =>
      IO.eprintln message
      return 2

end Loam.YearCli
