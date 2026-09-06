import Loam.Prototype.VerifiedTui12.Cli

/-!
# Record editor prototype 13 entry point

This uniquely named executable entry point avoids the historical collision with
`prototype/scheduled-workspace-12`, which also owns `loamUiPrototype12` / `VerifiedTui12`.

The underlying form experiment is unchanged; this file only gives it an
unambiguous executable identity for dogfood.
-/

def main : IO Unit :=
  Loam.Prototype.VerifiedTui12.Cli.run
