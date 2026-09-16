import Loam.Cli.Movement.Proposal
import Loam.HouseholdCommand

namespace Loam.MovementProposalRecordCli

set_option autoImplicit false

private def resolveRootPath (explicit : Option String) : IO (Except String String) := do
  match explicit with
  | some path =>
      if path.isEmpty then return .error "loam: data directory must not be empty"
      return .ok path
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok path
      | none => return .ok "../loam-data"

private def showRecorded
    (proposalPath : String)
    (draft : Loam.MovementAdmission.Draft)
    (eventId : Loam.Core.EventId) : IO Unit := do
  IO.println "LOAM Movement proposal publication"
  IO.println ("source: " ++ proposalPath)
  IO.println ("date: " ++ draft.validOn)
  IO.println ("effects: " ++ toString draft.effects.length)
  IO.println ("movement: " ++ toString draft.total ++ " jpy")
  match draft.description with
  | some text => IO.println ("description: " ++ text)
  | none => pure ()
  IO.println ("event: " ++ eventId.token)
  IO.println "[ok] proposal transport parsed"
  IO.println "[ok] authoritative Movement admission re-run under writer ownership"
  IO.println "[ok] canonical Actual publication complete"
  IO.println "source continuity and duplicate detection are not claimed"

/--
Record one machine-readable Movement proposal through the canonical household
writer.

Calling this entrance is an explicit publication request. It does not trust a
previous read-only proposal review, reserve a reviewed EventId, or bypass current
authority. `HouseholdCommand.record` re-enters the ordinary writer-owned
Movement publisher, which reloads authority and may still refuse.
-/
def recordFile (proposalPath rootPath : String) : IO UInt32 := do
  let source := System.FilePath.mk proposalPath
  if !(← source.pathExists) then
    IO.eprintln "loam: Movement proposal file not found"
    return 2
  let text ← IO.FS.readFile source
  match Loam.MovementProposal.parse? text with
  | .error message =>
      IO.eprintln message
      IO.eprintln "loam: proposal transport refused; no LOAM persistence was written"
      return 2
  | .ok draft =>
      match ← Loam.HouseholdCommand.record (System.FilePath.mk rootPath) draft with
      | .error message =>
          IO.eprintln message
          IO.eprintln "loam: Movement proposal publication refused"
          return 2
      | .ok eventId =>
          showRecorded proposalPath draft eventId
          return 0

private def usage : String :=
  "Record one machine-readable Movement proposal through canonical publication:\n" ++
  "  ./tools/loam movement-proposal-record PROPOSAL_FILE [LOAM_DATA_DIR]\n\n" ++
  "Invocation is an explicit write request. The writer re-reads current authority and may refuse even after an earlier read-only review.\n" ++
  "No external source identity, duplicate detection, or source-to-LOAM mapping is retained."

def run (args : List String) : IO UInt32 := do
  match args with
  | [proposalPath] =>
      match ← resolveRootPath none with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok rootPath => recordFile proposalPath rootPath
  | [proposalPath, rootPath] =>
      match ← resolveRootPath (some rootPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok resolved => recordFile proposalPath resolved
  | _ =>
      IO.eprintln usage
      return 2

end Loam.MovementProposalRecordCli

def main (args : List String) : IO UInt32 :=
  Loam.MovementProposalRecordCli.run args
