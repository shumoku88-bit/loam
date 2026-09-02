import Loam.Core.Event
import Loam.Persistence

namespace Loam.BalanceViewConfig

open Loam.Core

set_option autoImplicit false

/-!
# Replaceable balance-view configuration

This file is application configuration, not a canonical LOAM fact stream.
Each row selects one neutral `Locus × Measure` coordinate for the current
balance view:

```text
<locus-token><TAB><measure-token>
```

There is deliberately no identity, append-only history, correction relation,
accounting role, or winner semantics. Row order is presentation order only.
Duplicate rows are harmless and may be normalized by callers.
-/

private def decodeCoordinateRow? (row : String) : Option EffectCoordinate :=
  match row.splitOn "\t" with
  | [locusToken, measureToken] =>
      if Loam.Persistence.validToken locusToken &&
          Loam.Persistence.validToken measureToken then
        some ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
      else
        none
  | _ => none

private def dropOneTrailingEmpty : List String → List String
  | rows =>
      match rows.reverse with
      | "" :: rest => rest.reverse
      | _ => rows

/-- Decode the complete current balance-view config, failing closed on bad rows. -/
def decode? (input : String) : Option (List EffectCoordinate) :=
  (dropOneTrailingEmpty (input.splitOn "\n")).mapM decodeCoordinateRow?

/--
Load current balance-view configuration.

A missing file means that no coordinates are selected yet. This is not the same
as inventing a balance or a zero quantity; it is only an empty current question.
-/
def load? (path : System.FilePath) : IO (Option (List EffectCoordinate)) := do
  if ← path.pathExists then
    return decode? (← IO.FS.readFile path)
  else
    return some []

end Loam.BalanceViewConfig
