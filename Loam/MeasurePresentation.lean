import Loam.Core.Measure
import Loam.Persistence.TokenSyntax

namespace Loam.MeasurePresentation

open Loam.Core

set_option autoImplicit false

/-!
# Measure decimal presentation

Core `Quantity` remains an exact integer number of indivisible quanta. This
module provides an optional human-facing convention for rendering and parsing
those quanta as fixed-point decimal text for one `MeasureId`.

The convention is deliberately outside `MeasureId`: Measure identity remains
opaque and carries no built-in currency or dimensional semantics.

A scale of 2 means:

```text
1234 quanta <-> 12.34 displayed units
```

Missing metadata retains the historical LOAM behavior: scale 0, so one displayed
integer maps to one quantum.

This module does not perform valuation, currency conversion, rounding, or
cross-Measure arithmetic.
-/

structure Metadata where
  measure : MeasureId
  scale : Nat
  deriving Repr, DecidableEq

private def hasDuplicateMeasure : List Metadata → Bool
  | [] => false
  | row :: rest =>
      rest.any (fun other => other.measure = row.measure) || hasDuplicateMeasure rest

/--
Decode a tiny replaceable TSV dictionary:

```text
# measure<TAB>decimal-scale
jpy<TAB>0
usd<TAB>2
ils<TAB>2
```

Scale is intentionally bounded. Nine decimal places is already far beyond the
ordinary household-currency use that earned this boundary and prevents absurd
presentation configuration from creating huge accidental input multipliers.
-/
def decode? (input : String) : Option (List Metadata) := do
  let lines :=
    (input.splitOn "\n").filter fun line =>
      !line.isEmpty && !line.startsWith "#"
  let rows ← lines.mapM fun line => do
    match line.splitOn "\t" with
    | [token, scaleText] =>
        if !Loam.Persistence.validToken token then
          none
        else
          let scale ← scaleText.toNat?
          if scale > 9 then none
          else some ({ measure := ⟨token⟩, scale := scale } : Metadata)
    | _ => none
  if hasDuplicateMeasure rows then none else some rows

/-- Missing metadata means the established integer presentation. -/
def scaleFor (metadata : List Metadata) (measure : MeasureId) : Nat :=
  match metadata.find? (fun row => row.measure = measure) with
  | some row => row.scale
  | none => 0

private def factor (scale : Nat) : Nat :=
  10 ^ scale

private def parseUnsigned? (scale : Nat) (text : String) : Option Nat := do
  match text.splitOn "." with
  | [whole] =>
      let wholeValue ← whole.toNat?
      some (wholeValue * factor scale)
  | [whole, fractional] =>
      if scale = 0 || whole.isEmpty || fractional.isEmpty || fractional.length > scale then
        none
      else
        let wholeValue ← whole.toNat?
        let fractionalValue ← fractional.toNat?
        some
          (wholeValue * factor scale +
            fractionalValue * factor (scale - fractional.length))
  | _ => none

/--
Parse exact signed fixed-point text without floating point or rounding.

For scale 2, `12`, `12.3`, and `12.34` are accepted and map to 1200,
1230, and 1234 quanta. Extra fractional digits are refused.
-/
def parseQuanta? (metadata : List Metadata) (measure : MeasureId) (text : String) : Option Int := do
  if text.isEmpty then none else
  let (negative, body) :=
    match text.toList with
    | '-' :: rest => (true, String.ofList rest)
    | '+' :: rest => (false, String.ofList rest)
    | _ => (false, text)
  if body.isEmpty then none else
  let magnitude ← parseUnsigned? (scaleFor metadata measure) body
  let value : Int := Int.ofNat magnitude
  some (if negative then -value else value)

private def zeroPadLeft (width : Nat) (text : String) : String :=
  if text.length >= width then text
  else String.ofList (List.replicate (width - text.length) '0') ++ text

/-- Render exact quanta using the selected fixed-point convention. -/
def formatQuanta (metadata : List Metadata) (measure : MeasureId) (quanta : Int) : String :=
  let scale := scaleFor metadata measure
  if scale = 0 then
    toString quanta
  else
    let magnitude := quanta.natAbs
    let base := factor scale
    let whole := magnitude / base
    let fractional := magnitude % base
    let sign := if quanta < 0 then "-" else ""
    sign ++ toString whole ++ "." ++ zeroPadLeft scale (toString fractional)

def configFileName : String := "measure-presentation.tsv"

/-- Canonical presentation path next to one household Actual file. -/
def configPathForActualFile (actualFile : System.FilePath) : System.FilePath :=
  let dataDir := actualFile.parent.getD (System.FilePath.mk ".")
  dataDir / "config" / configFileName

/-- Load optional Measure presentation metadata. Missing configuration is scale-0 compatibility. -/
def loadMetadata
    (dataDir : System.FilePath) : IO (Except String (List Metadata)) := do
  let path := dataDir / "config" / configFileName
  try
    if ← path.pathExists then
      match decode? (← IO.FS.readFile path) with
      | some metadata => return .ok metadata
      | none => return .error "measure presentation config is malformed"
    else
      return .ok []
  catch error =>
    return .error ("measure presentation config unreadable: " ++ error.toString)

/-- Load the presentation convention associated with one Actual file path. -/
def loadForActualFile
    (actualFile : System.FilePath) : IO (Except String (List Metadata)) := do
  let dataDir := actualFile.parent.getD (System.FilePath.mk ".")
  loadMetadata dataDir

end Loam.MeasurePresentation
