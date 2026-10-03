import Loam.Presentation.ReadState

def main : IO Unit := do
  let loadedNone : Loam.Presentation.ReadState (Option Nat) := .loaded none
  match loadedNone with
  | .loaded none => pure ()
  | _ => throw (IO.userError "loaded none collapsed into read unavailability")

  let failed : Loam.Presentation.ReadState Nat := .failed "diagnostic"
  match Loam.Presentation.ReadState.map failed (fun value => value + 1) with
  | .failed "diagnostic" => pure ()
  | _ => throw (IO.userError "ReadState.map changed failure classification or diagnostic")

  match Loam.Presentation.ReadState.fromExcept (Except.ok 7 : Except String Nat) with
  | .loaded 7 => pure ()
  | _ => throw (IO.userError "ReadState.fromExcept did not preserve a loaded value")

  match Loam.Presentation.ReadState.fromExcept (Except.error "refused" : Except String Nat) with
  | .failed "refused" => pure ()
  | _ => throw (IO.userError "ReadState.fromExcept did not classify refusal as failed")

  IO.println "Presentation ReadState: loaded emptiness and failure classification passed."
