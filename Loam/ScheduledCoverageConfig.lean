import Loam.ActualDate
import Loam.Persistence.TokenSyntax

namespace Loam.ScheduledCoverageConfig

set_option autoImplicit false

/-!
# Replaceable Scheduled coverage rules

This is read-side application configuration, not retained Scheduled authority.

Each TSV row declares one monitoring expectation:

```text
<rule-token><TAB><anchor-date><TAB><every-months><TAB><negative-locus[,negative-locus...]><TAB><positive-locus[,positive-locus...]>
```

The rule says only which calendar months a coverage report should expect to find
an explicit current-open Scheduled occurrence matching the exact negative- and
positive-Locus sets. It does not create occurrences, retain recurrence or Series identity, prove
contract identity, or change Scheduled lifecycle semantics.
-/

structure Rule where
  name : String
  anchor : String
  everyMonths : Nat
  negativeLoci : List String
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
  let [name, anchor, stepText, negativeText, positiveText] := row.splitOn "\t" | none
  let everyMonths ← stepText.toNat?
  let negativeLoci := normalizedLoci negativeText
  let positiveLoci := normalizedLoci positiveText
  if Loam.Persistence.validToken name &&
      Loam.ActualDate.validIsoDate anchor &&
      decide (everyMonths > 0) &&
      !negativeLoci.isEmpty &&
      !positiveLoci.isEmpty &&
      negativeLoci.all Loam.Persistence.validToken &&
      positiveLoci.all Loam.Persistence.validToken &&
      decide (negativeLoci.eraseDups.length = negativeLoci.length) &&
      decide (positiveLoci.eraseDups.length = positiveLoci.length) then
    some {
      name := name
      anchor := anchor
      everyMonths := everyMonths
      negativeLoci := negativeLoci
      positiveLoci := positiveLoci
    }
  else
    none

private def uniqueRows : List Rule → Bool
  | [] => true
  | rule :: rest =>
      !(rest.any fun other =>
        other.name == rule.name ||
          (other.negativeLoci == rule.negativeLoci &&
           other.positiveLoci == rule.positiveLoci)) &&
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


private def encodeRule (rule : Rule) : String :=
  rule.name ++ "\t" ++ rule.anchor ++ "\t" ++ toString rule.everyMonths ++ "\t" ++
    String.intercalate "," rule.negativeLoci ++ "\t" ++
    String.intercalate "," rule.positiveLoci

/-- Encode one complete monitoring configuration. The emitted image must decode again. -/
def encode? (rules : List Rule) : Option String := do
  let text :=
    if rules.isEmpty then ""
    else String.intercalate "\n" (rules.map encodeRule) ++ "\n"
  let _ ← decode? text
  some text

private def sameShape (left right : Rule) : Bool :=
  left.negativeLoci == right.negativeLoci &&
    left.positiveLoci == right.positiveLoci

/--
Insert or replace one read-side monitoring rule.

An existing signed-Locus selector keeps its stable display name while its anchor
and cadence may be changed. A duplicate display name for a different selector is
rejected instead of silently renaming household vocabulary.
-/
def upsertRule (rules : List Rule) (rule : Rule) : Except String (List Rule) :=
  match rules.find? (fun existing => sameShape existing rule) with
  | some existing =>
      let replacement := { rule with name := existing.name }
      .ok <| rules.map fun current =>
        if sameShape current existing then replacement else current
  | none =>
      if rules.any (fun existing => existing.name == rule.name) then
        .error ("loam: Scheduled coverage name already monitors a different plan: " ++ rule.name)
      else
        .ok (rules ++ [rule])

/--
Publish a complete read-side monitoring image through staging, typed re-decoding,
and one filesystem rename. This writes monitoring configuration only; it never
publishes Scheduled evidence.
-/
def save (path : System.FilePath) (rules : List Rule) : IO (Except String Unit) := do
  let text ←
    match encode? rules with
    | some text => pure text
    | none => return .error "loam: Scheduled coverage encoder rejected monitoring rules"
  if let some parent := path.parent then
    IO.FS.createDirAll parent
  let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
  IO.FS.writeFile stage text
  let staged ← IO.FS.readFile stage
  if staged != text then
    return .error ("loam: staged Scheduled coverage mismatch: " ++ stage.toString)
  match decode? staged with
  | none => return .error "loam: staged Scheduled coverage failed typed decoding"
  | some _ => pure ()
  IO.FS.rename stage path
  return .ok ()

/-- Load, upsert, and safely republish one monitoring rule. -/
def upsertAt (path : System.FilePath) (rule : Rule) : IO (Except String Unit) := do
  try
    let rules ←
      match ← load? path with
      | none => return .error "loam: Scheduled coverage config is malformed"
      | some rules => pure rules
    let next ←
      match upsertRule rules rule with
      | .error message => return .error message
      | .ok next => pure next
    save path next
  catch error =>
    return .error ("loam: Scheduled coverage config update failed: " ++ error.toString)

end Loam.ScheduledCoverageConfig
