import Loam.ActualDate
import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
import Loam.CycleBudgetReview
import Loam.PurposeCatalog
import Loam.ScheduledReview
import Loam.Web.Snapshot

namespace Loam.Web.Cli

set_option autoImplicit false

private def resolveDataDir (explicit : Option String) : IO (Except String System.FilePath) := do
  match explicit with
  | some path =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")

private def loadScheduled
    (dataDir : System.FilePath) : IO (Except String (List Loam.ScheduledReview.Record)) := do
  match ← Loam.ScheduledReview.loadHouseholdEvidence dataDir dataDir with
  | .error message => return .error message
  | .ok evidence => return Loam.ScheduledReview.currentOpenRecords evidence

private def currentPurposeMetadata
    (dataDir : System.FilePath) : IO (List Loam.PurposeCatalog.Metadata) := do
  match ← Loam.PurposeCatalog.loadMetadata dataDir with
  | .ok metadata => return metadata
  | .error _ => return []

private def renderCurrent
    (dataDir : System.FilePath) : IO (Except String String) := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | return .error "loam: could not determine the local date"

  let actual ← Loam.ActualReview.loadRecordsFromActual dataDir
  let scheduled ← loadScheduled dataDir
  let attention ← Loam.AttentionReview.loadEvidence (dataDir / "attention.loam")
  let budget ← Loam.CycleBudgetReview.loadSnapshotAt dataDir dataDir observedAt
  let capacity ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir
  let purposeMetadata ← currentPurposeMetadata dataDir

  let snapshot : Loam.Web.Snapshot.Snapshot := {
    observedAt := observedAt
    actual := actual
    scheduled := scheduled
    attention := attention
    budget := budget
    capacity := capacity
    purposeMetadata := purposeMetadata
  }

  return .ok (Loam.Web.Snapshot.render snapshot)

private def renderTo
    (dataDir output : System.FilePath) : IO UInt32 := do
  match ← renderCurrent dataDir with
  | .error message =>
      IO.eprintln message
      return 2
  | .ok html =>
      if output.toString = "-" then
        IO.print html
        return 0
      try
        IO.FS.writeFile output html
        IO.println ("LOAM Web snapshot: " ++ output.toString)
        return 0
      catch error =>
        IO.eprintln ("loam: could not write Web snapshot: " ++ error.toString)
        return 2

private def usage : String :=
  "Render the read-only LOAM Web frontend:\n" ++
  "  loamWeb [LOAM_DATA_DIR] [OUTPUT_HTML]\n\n" ++
  "Defaults: LOAM_DATA_DIR or ../loam-data; output ./loam-web.html.\n" ++
  "Use OUTPUT_HTML '-' to write only the current HTML document to stdout.\n" ++
  "The page consumes shared Review boundaries and performs no writes."

def run (args : List String) : IO UInt32 := do
  match args with
  | [] =>
      match ← resolveDataDir none with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir => renderTo dataDir (System.FilePath.mk "loam-web.html")
  | [dataPath] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir => renderTo dataDir (System.FilePath.mk "loam-web.html")
  | [dataPath, outputPath] =>
      match ← resolveDataDir (some dataPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok dataDir => renderTo dataDir (System.FilePath.mk outputPath)
  | _ =>
      IO.eprintln usage
      return 2

end Loam.Web.Cli

def main (args : List String) : IO UInt32 :=
  Loam.Web.Cli.run args
