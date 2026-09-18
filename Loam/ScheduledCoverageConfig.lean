import Loam.ActualDate
import Loam.Persistence.TokenSyntax

namespace Loam.ScheduledCoverageConfig

set_option autoImplicit false

/-!
# Replaceable Scheduled coverage rules

This is read-side application configuration, not retained Scheduled authority.

Each TSV row declares one monitoring expectation:

```text
<rule-token><TAB><anchor-date><TAB><every-months><TAB><positive-locus[,positive-locus...]>
```

The rule says only which calendar months a coverage report should expect to find
an explicit current-open Scheduled occurrence matching the exact positive-Locus
set. It does not create occurrences, retain recurrence or Series identity, prove
contract identity, or change Scheduled lifecycle semantics.
-/

structure Rule where
  name : String
  anchor : String
  everyMonths : Nat
  positiveLoci : List String
  deriving Repr, DecidableEq

private def dropOneTrailingEmpty : List String → List String
  | rows =>
      match rows.reverse with
      | "" :: rest => rest.reverse
      | _ => rows

private def normalizedLoci (text : String) : List String :=
  (text.splitOn ",").mergeSort fun left right => left <= right

private def decodeRow? (row : String) : Option Rule := do
  let [name, anchor, stepText, lociText] := row.splitOn "\t" | none
  let everyMonths ← stepText.toNat?
  let loci := normalizedLoci lociText
  if Loam.Persistence.validToken name &&
      Loam.ActualDate.validIsoDate anchor &&
      decide (everyMonths > 0) &&
      decide (!loci.isEmpty) &&
      loci.all Loam.Persistence.validToken &&
      decide (loci.eraseDups.length = loci.length) then
    some {
      name := name
      anchor := anchor
      everyMonths := everyMonths
      positiveLoci := loci
    }
  else
    none

private def uniqueRows : List Rule → Bool
  | [] => true
  | rule :: rest =>
      !(rest.any fun other =>
        other.name == rule.name || other.positiveLoci == rule.positiveLoci) &&
      uniqueRows rest

/-- Decode one complete current coverage configuration, failing closed on bad rows. -/
def decode? (input : String) : Option (List Rule) := do
  let rules ← (dropOneTrailingEmpty (input.splitOn "\n")).mapM decodeRow?
  if uniqueRows rules then some rules else none

/--
Load current Scheduled coverage rules.

A missing file means no coverage rules are configured. It never means that
Scheduled is complete or that any recurrence should be inferred.
-/
def load? (path : System.FilePath) : IO (Option (List Rule)) := do
  if ← path.pathExists then
    return decode? (← IO.FS.readFile path)
  else
    return some []

end Loam.ScheduledCoverageConfig
