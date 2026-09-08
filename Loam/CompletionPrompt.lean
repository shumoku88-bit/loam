import Loam.Core.EventMemory

namespace Loam.CompletionPrompt

set_option autoImplicit false

private def addIfAbsent (tokens : List String) (token : String) : List String :=
  if token ∈ tokens then tokens else tokens ++ [token]

/--
Collect the Locus tokens that are actually present in recorded Effects.

This is a recognition projection only. Retained order is a stable display
convenience inherited from the current memory representation; it carries no
temporal, priority, permission, authority, or accounting meaning.
-/
def knownLoci (memory : Loam.Core.EventMemory) : List String :=
  memory.events.foldl
    (fun loci event =>
      event.effects.foldl
        (fun current effect => addIfAbsent current effect.locus.token)
        loci)
    []

end Loam.CompletionPrompt
