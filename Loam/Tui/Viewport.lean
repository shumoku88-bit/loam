import Loam.Tui.Kernel

namespace Loam.Tui.Viewport

open Loam.Tui.Kernel

set_option autoImplicit false

/-!
# Lazy viewport source

A small presentation-only abstraction for long TUI bodies.

A Source knows its logical row extent and can materialize only a requested
contiguous slice. It carries no report semantics, selection state, persistence,
or scrolling policy.

Short surfaces can use `ofList`. Long surfaces can provide a lazy `slice`
without constructing rows that are outside the active viewport.
-/

structure Source (α : Type) where
  extent : Nat
  slice : Nat → Nat → List α

def empty {α : Type} : Source α :=
  { extent := 0, slice := fun _ _ => [] }

def ofList {α : Type} (values : List α) : Source α :=
  {
    extent := values.length
    slice := fun offset count => (values.drop offset).take count
  }

def append {α : Type} (left right : Source α) : Source α :=
  {
    extent := left.extent + right.extent
    slice := fun offset count =>
      if count = 0 then
        []
      else if offset < left.extent then
        let leftCount := min count (left.extent - offset)
        left.slice offset leftCount ++
          right.slice 0 (count - leftCount)
      else
        right.slice (offset - left.extent) count
  }

def concat {α : Type} (sources : List (Source α)) : Source α :=
  sources.foldl append empty

end Loam.Tui.Viewport
