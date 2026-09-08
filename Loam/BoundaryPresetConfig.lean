import Loam.ActualDate
import Loam.Persistence

namespace Loam.BoundaryPresetConfig

set_option autoImplicit false

/-!
# Replaceable report-boundary presets

This file defines application configuration, not a canonical LOAM fact stream.
Each TSV row names one reusable query preset followed by its explicitly known
boundary dates:

```text
<preset-token><TAB><YYYY-MM-DD><TAB><YYYY-MM-DD>...
```

Boundary dates must be real ISO dates and strictly increasing. A preset needs at
least two boundaries because a report window is always an adjacent half-open
`[start, end)` pair. Preset names are unique inside one current configuration.

There is deliberately no retained cycle identity, append-only history, learned
time, correction relation, winner semantics, recurrence generation, or fact
membership. Editing this file changes future query selection only.
-/

structure Preset where
  name : String
  boundaries : List String
  deriving Repr, DecidableEq

private def dropOneTrailingEmpty : List String → List String
  | rows =>
      match rows.reverse with
      | "" :: rest => rest.reverse
      | _ => rows

private def strictlyIncreasing : List String → Bool
  | [] | [_] => true
  | first :: second :: rest =>
      decide (first < second) && strictlyIncreasing (second :: rest)

private def decodeRow? (row : String) : Option Preset :=
  match row.splitOn "\t" with
  | name :: boundaries =>
      if Loam.Persistence.validToken name &&
          decide (boundaries.length >= 2) &&
          boundaries.all Loam.ActualDate.validIsoDate &&
          strictlyIncreasing boundaries then
        some { name := name, boundaries := boundaries }
      else
        none
  | _ => none

private def uniqueNames : List Preset → Bool
  | [] => true
  | preset :: rest =>
      !(rest.any fun other => other.name == preset.name) && uniqueNames rest

/-- Decode one complete current preset configuration, failing closed on bad rows. -/
def decode? (input : String) : Option (List Preset) := do
  let presets ← (dropOneTrailingEmpty (input.splitOn "\n")).mapM decodeRow?
  if uniqueNames presets then some presets else none

/--
Load current report-boundary presets.

A missing file means that no named presets are configured yet. This does not
invent a household boundary, recurrence, or cycle; Calendar Month and explicit
Custom coordinates remain available presentation questions.
-/
def load? (path : System.FilePath) : IO (Option (List Preset)) := do
  if ← path.pathExists then
    return decode? (← IO.FS.readFile path)
  else
    return some []

private def adjacentWindow? (selected : String) : List String → Option (String × String)
  | start :: endExclusive :: rest =>
      if start <= selected then
        if selected < endExclusive then
          some (start, endExclusive)
        else
          adjacentWindow? selected (endExclusive :: rest)
      else
        none
  | _ => none

/-- Resolve only an explicitly represented adjacent window around `selected`. -/
def windowForDate? (preset : Preset) (selected : String) : Option (String × String) :=
  if Loam.ActualDate.validIsoDate selected then
    adjacentWindow? selected preset.boundaries
  else
    none

end Loam.BoundaryPresetConfig
