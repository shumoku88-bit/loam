import Loam.MeasurePresentation
import Loam.MovementAdmission
import Loam.Persistence.TokenSyntax

namespace Loam.Presentation.Record

set_option autoImplicit false

/-!
# Surface-neutral Record input and preview

This module owns only the small presentation/action boundary shared by frontends
that collect one ordinary practical Movement.

It does not own focus, keys, HTML, terminal rendering, canonical paths, writer
locking, durable identity, persistence, or household truth. Successful preview
means only that the collected input can become a Movement draft and is admissible
against the supplied in-memory world. Final publication must still go through
`HouseholdCommand.record`, which re-reads authoritative state.
-/

/-- One human-entered signed posting row. Row order has no semantic meaning. -/
structure Row where
  locus : String := ""
  amount : String := ""
  deriving Repr, DecidableEq, Inhabited

/--
Surface-neutral Record form data.

Renderers may keep additional local state such as focus, cursor, field errors,
or browser navigation, but those concerns do not enter this boundary.
-/
structure Input where
  date : String
  description : String := ""
  measure : String := "jpy"
  rows : Array Row := #[{}, {}]
  deriving Repr, DecidableEq, Inhabited

/--
A successful read-only Record preview.

The draft is deliberately the only retained semantic value. No Event identity is
reserved and no persistence occurs; final publication re-enters current authority.
-/
structure Preview where
  draft : Loam.MovementAdmission.Draft
  deriving Repr, DecidableEq

private def draftUsingPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (input : Input) : Except String Loam.MovementAdmission.Draft := do
  if !Loam.Persistence.validToken input.measure then
    throw "Enter a nonempty single-line Measure token."
  let measure : Loam.Core.MeasureId := ⟨input.measure⟩
  let scale := Loam.MeasurePresentation.scaleFor metadata measure
  let mut effects := []
  let mut total := 0
  for index in List.range input.rows.size do
    let row := input.rows[index]!
    let some amount := Loam.MeasurePresentation.parseQuanta? metadata measure row.amount
      | throw
          ("Enter a nonzero signed " ++ input.measure ++ " amount with at most " ++
            toString scale ++ " decimal places for every posting.")
    if amount = 0 then
      throw
        ("Enter a nonzero signed " ++ input.measure ++ " amount with at most " ++
          toString scale ++ " decimal places for every posting.")
    effects := effects ++ [Loam.Core.Effect.ofQuantity
      ⟨"effect-" ++ toString (index + 1)⟩ ⟨row.locus⟩ measure
      (Loam.Core.Quantity.ofQuanta amount)]
    if amount > 0 then total := total + amount
  let draft : Loam.MovementAdmission.Draft := {
    validOn := input.date
    description := if input.description.isEmpty then none else some input.description
    effects := effects
    relations := []
    discharges := []
    total := total
  }
  Loam.MovementAdmission.validateDraft draft
  pure draft

/-- Parse scale-0 Record input into the existing Movement semantic draft. -/
def draft? (input : Input) : Except String Loam.MovementAdmission.Draft :=
  draftUsingPresentation? [] input

/-- Parse Record input under one explicit Measure presentation convention. -/
def draftWithPresentation?
    (metadata : List Loam.MeasurePresentation.Metadata)
    (input : Input) : Except String Loam.MovementAdmission.Draft :=
  draftUsingPresentation? metadata input

/--
Build and check one Record preview against an already-loaded world.

This performs no IO and no persistence. `MovementAdmission.admit?` is used only
as the existing semantic admission question; its hypothetical allocated identity
is intentionally discarded.
-/
def preview?
    (world : Loam.MovementAdmission.World)
    (metadata : List Loam.MeasurePresentation.Metadata)
    (input : Input) : Except String Preview := do
  let draft ← draftWithPresentation? metadata input
  let _ ← Loam.MovementAdmission.admit? world draft
  pure { draft := draft }

end Loam.Presentation.Record
