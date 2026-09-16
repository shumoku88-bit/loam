import Loam.LocusCatalog

namespace Loam.Tui.LocusPicker

set_option autoImplicit false

/--
Presentation-only candidates for one Locus text field.

Empty text intentionally shows the whole current admitted catalog. An exact
matching token is ordered first so completing on an already fully-typed Locus
is an identity rather than an unwanted substitution.
-/
def candidates
    (catalog : Loam.LocusCatalog.Catalog) (entered : String) : Loam.LocusCatalog.Catalog :=
  let results := Loam.LocusCatalog.search catalog entered
  if entered.isEmpty then results
  else
    match results.partition (fun entry => entry.locus.token == entered) with
    | (exact, rest) => exact ++ rest

/-- Selected candidate under a local cursor. -/
def selected?
    (catalog : Loam.LocusCatalog.Catalog) (entered : String) (index : Nat) :
    Option Loam.LocusCatalog.Entry :=
  let options := candidates catalog entered
  if options.isEmpty then none else options[index % options.length]?

/-- Move a local candidate cursor without changing the query or catalog. -/
def move
    (catalog : Loam.LocusCatalog.Catalog) (entered : String)
    (index : Nat) (back : Bool) : Nat :=
  let options := candidates catalog entered
  if options.isEmpty then 0
  else
    let count := options.length
    if back then (index + count - 1) % count else (index + 1) % count

/-- Human-facing compact row; token remains visible because it is the stable identity. -/
def display (entry : Loam.LocusCatalog.Entry) : String :=
  if entry.label == entry.locus.token then entry.locus.token
  else entry.locus.token ++ "  " ++ entry.label

end Loam.Tui.LocusPicker
