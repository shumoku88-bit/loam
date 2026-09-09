import Loam.LocusAdmissionPublisher
import Loam.Tui.Kernel
import Loam.Tui.LocusAdmissionAdministration
import Loam.Tui.Runtime
import Loam.Tui.Terminal

namespace Loam.Tui.LocusAdmissionAdministrationSession

open Loam.Tui.Kernel
open Loam.Tui.Runtime

set_option autoImplicit false

/-!
# Locus admission administration terminal session

The session owns only local interaction state. The authoritative write is delegated
to `LocusAdmissionPublisher.publishManifestAdmission`, which re-reads Movement
manifest authority under the shared CURRENT ownership anchor.
-/

partial def run
    (bounds : Bounds)
    (root : System.FilePath)
    (state : Loam.Tui.LocusAdmissionAdministration.State)
    (frame : CompiledWidget) : IO String := do
  let key ← Loam.Tui.Terminal.readKey
  let step := Loam.Tui.LocusAdmissionAdministration.update state key
  if step.cancel then
    return "Locus admission cancelled."
  match step.publish with
  | some draft =>
      match ← Loam.LocusAdmissionPublisher.publishManifestAdmission root.toString draft with
      | .ok receipt =>
          return "Admitted Locus " ++ receipt.locus.token ++ " for new writes. Vocabulary: " ++
            toString receipt.previousCount ++ " -> " ++ toString receipt.currentCount ++ "."
      | .error message => return "Locus admission refused: " ++ message
  | none =>
      let nextFrame := compileWidget (Loam.Tui.LocusAdmissionAdministration.view bounds step.state)
      Loam.Tui.Terminal.emitDirtyDiff bounds 0 0 frame nextFrame
      run bounds root step.state nextFrame

end Loam.Tui.LocusAdmissionAdministrationSession
