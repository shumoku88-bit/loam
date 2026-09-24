namespace Loam.Presentation

set_option autoImplicit false

/-!
# Presentation read state

This type names only the small set of states a presentation surface must
distinguish before it renders a shared Review answer.

It is not household semantics, persistence state, or a replacement for existing
structured domain/load errors.
-/

inductive ReadState (α : Type u) where
  | notRequested
  | unavailable
  | failed (message : String)
  | loaded (value : α)
deriving Repr

namespace ReadState

def fromExcept (result : Except String α) : ReadState α :=
  match result with
  | .error message => .failed message
  | .ok value => .loaded value

def map (state : ReadState α) (f : α → β) : ReadState β :=
  match state with
  | .notRequested => .notRequested
  | .unavailable => .unavailable
  | .failed message => .failed message
  | .loaded value => .loaded (f value)

end ReadState

end Loam.Presentation
