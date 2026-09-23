import Loam.Cli.Movement.Proposal
import Loam.MovementDraftReview

namespace Loam.MovementProposalCli

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

private def showAccepted
    (path : String) (draft : Loam.MovementAdmission.Draft) : IO Unit := do
  IO.println "LOAM Movement proposal review"
  IO.println ("source: " ++ path)
  IO.println ("date: " ++ draft.validOn)
  IO.println ("effects: " ++ toString draft.effects.length)
  IO.println ("movement: " ++ toString draft.total ++ " jpy")
  match draft.description with
  | some text => IO.println ("description: " ++ text)
  | none => pure ()
  IO.println "[ok] proposal transport parsed"
  IO.println "[ok] admissible against current household evidence"
  IO.println "[ok] persistence: none"
  IO.println "[ok] Event identity: not reserved"
  IO.println "proposal only; source continuity and duplicate detection are not claimed"

/--
Parse and review one machine-readable Movement proposal without publication.

The proposal file is an observation transport, not an authority source. A
successful review does not reserve identity, persist source continuity, or make
a future publication automatic.
-/
def reviewFile (proposalPath rootPath : String) : IO UInt32 := do
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
      match ← Loam.MovementDraftReview.check (System.FilePath.mk rootPath) draft with
      | .error message =>
          IO.eprintln message
          IO.eprintln "loam: Movement proposal not admitted; no LOAM persistence was written"
          return 2
      | .ok () =>
          showAccepted proposalPath draft
          return 0

private def usage : String :=
  "Review one machine-readable Movement proposal without publishing:\n" ++
  "  ./tools/loam movement-proposal PROPOSAL_FILE [LOAM_DATA_DIR]\n\n" ++
  "Format v1 begins with LOAM-MOVEMENT-PROPOSAL<TAB>1 and supports date, description, effect, relation, and discharge rows.\n" ++
  "The command never publishes, reserves an EventId, or retains source-to-LOAM identity."

def run (args : List String) : IO UInt32 := do
  match args with
  | [proposalPath] =>
      match ← resolveRootPath none with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok rootPath => reviewFile proposalPath rootPath
  | [proposalPath, rootPath] =>
      match ← resolveRootPath (some rootPath) with
      | .error message =>
          IO.eprintln message
          return 2
      | .ok resolved => reviewFile proposalPath resolved
  | _ =>
      IO.eprintln usage
      return 2

end Loam.MovementProposalCli
