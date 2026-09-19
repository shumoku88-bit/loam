import Loam.ActualDate
import Loam.ActualReview
import Loam.AttentionReview
import Loam.CapacityReview
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

private def renderTo
    (dataDir output : System.FilePath) : IO UInt32 := do
  let some observedAt ← Loam.ActualDate.todayIso?
    | IO.eprintln "loam: could not determine the local date"
      return 2

  let actual ← Loam.ActualReview.loadRecordsFromActual dataDir
  let scheduled ← loadScheduled dataDir
  let attention ← Loam.AttentionReview.loadEvidence (dataDir / "attention.loam")
  let capacity ← Loam.CapacityReview.loadSnapshotFromHouseholdRoot dataDir

  let snapshot : Loam.Web.Snapshot.Snapshot := {
    observedAt := observedAt
    actual := actual
    scheduled := scheduled
    attention := attention
    capacity := capacity
  }

  try
    IO.FS.writeFile output (Loam.Web.Snapshot.render snapshot)
    IO.println ("LOAM Web snapshot: " ++ output.toString)
    IO.println "read-only; restart the web entrance to refresh canonical evidence"
    return 0
  catch error =>
    IO.eprintln ("loam: could not write Web snapshot: " ++ error.toString)
    return 2

private def usage : String :=
  "Render the read-only LOAM Web frontend:\n" ++
  "  loamWeb [LOAM_DATA_DIR] [OUTPUT_HTML]\n\n" ++
  "Defaults: LOAM_DATA_DIR or ../loam-data; output ./loam-web.html.\n" ++
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
