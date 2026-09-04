import Loam.Core

namespace Loam.Observation152

set_option autoImplicit false

/-!
# Observation 152 — typed-section codec pressure

Observation 151 selected typed framed sections as the surviving native wire-shape
candidate for a unified Actual generation. This observation does not define the
production format. It builds the smallest public synthetic codec that can pressure
the framing rules before any production parser or migration exists.

The codec keeps four semantic facets distinct:

- EventMemory
- ActualValidity
- EventDescription
- optional EventCorrection

The wire is a synthetic `List Nat`. Each section is framed as
`tag, payload-length, payload...`. Required sections have one canonical order and
the optional correction section, when present, is last.
-/

inductive SectionTag
  | events
  | validity
  | descriptions
  | corrections
  deriving Repr, DecidableEq

private def tagCode : SectionTag → Nat
  | .events => 1
  | .validity => 2
  | .descriptions => 3
  | .corrections => 4

private def tagOfCode? : Nat → Option SectionTag
  | 1 => some .events
  | 2 => some .validity
  | 3 => some .descriptions
  | 4 => some .corrections
  | _ => none

/-- Synthetic wire/version marker. It is format metadata, not household identity. -/
private def magic : List Nat := [76, 79, 65, 77, 1]

structure SyntheticActual where
  events : List Nat
  validity : List Nat
  descriptions : List Nat
  corrections : Option (List Nat)
  deriving Repr, DecidableEq

private def encodeSection (tag : SectionTag) (payload : List Nat) : List Nat :=
  [tagCode tag, payload.length] ++ payload

/-- Canonical encoder: required facets are ordered, optional correction is last. -/
def encode (actual : SyntheticActual) : List Nat :=
  let required :=
    encodeSection .events actual.events ++
    encodeSection .validity actual.validity ++
    encodeSection .descriptions actual.descriptions
  let optional :=
    match actual.corrections with
    | none => []
    | some payload => encodeSection .corrections payload
  magic ++ required ++ optional

private def takeExact? (n : Nat) (xs : List Nat) : Option (List Nat × List Nat) :=
  if n ≤ xs.length then
    some (xs.take n, xs.drop n)
  else
    none

/--
Parse framed sections with explicit fuel. Unknown tags and truncated payloads fail
closed before semantic reconstruction.
-/
private def parseSections : Nat → List Nat → Option (List (SectionTag × List Nat))
  | 0, [] => some []
  | 0, _ :: _ => none
  | Nat.succ _, [] => some []
  | Nat.succ fuel, tagCodeValue :: len :: rest =>
      match tagOfCode? tagCodeValue, takeExact? len rest with
      | some tag, some (payload, tail) =>
          match parseSections fuel tail with
          | some more => some ((tag, payload) :: more)
          | none => none
      | _, _ => none
  | Nat.succ _, _ :: [] => none

private def validSectionOrder (sections : List (SectionTag × List Nat)) : Bool :=
  let tags := sections.map Prod.fst
  decide (
    tags = [.events, .validity, .descriptions] ∨
    tags = [.events, .validity, .descriptions, .corrections])

private def payloadFor?
    (sections : List (SectionTag × List Nat))
    (tag : SectionTag) : Option (List Nat) :=
  match sections.find? (fun section => decide (section.1 = tag)) with
  | some (_, payload) => some payload
  | none => none

/--
Strict synthetic decoder. Version/header mismatch, framing damage, unknown tags,
duplicate/reordered sections, and missing required sections all fail closed.
-/
def decode (wire : List Nat) : Option SyntheticActual :=
  if wire.take magic.length ≠ magic then
    none
  else
    let body := wire.drop magic.length
    match parseSections body.length body with
    | none => none
    | some sections =>
        if !validSectionOrder sections then
          none
        else
          match payloadFor? sections .events,
                payloadFor? sections .validity,
                payloadFor? sections .descriptions with
          | some events, some validity, some descriptions =>
              some {
                events := events
                validity := validity
                descriptions := descriptions
                corrections := payloadFor? sections .corrections }
          | _, _, _ => none

private def sampleAbsentCorrection : SyntheticActual :=
  { events := [10, 11]
    validity := [20, 21]
    descriptions := [30]
    corrections := none }

private def samplePresentEmptyCorrection : SyntheticActual :=
  { sampleAbsentCorrection with corrections := some [] }

private def samplePresentCorrection : SyntheticActual :=
  { sampleAbsentCorrection with corrections := some [40, 41] }

/-- Required-facet sample round-trips exactly. -/
theorem required_roundtrip :
    decode (encode sampleAbsentCorrection) = some sampleAbsentCorrection := by
  decide

/-- Present correction payload round-trips exactly. -/
theorem correction_roundtrip :
    decode (encode samplePresentCorrection) = some samplePresentCorrection := by
  decide

/--
Absent optional correction remains distinguishable from a present-but-empty
correction section. The codec does not invent source presence.
-/
theorem optional_absence_is_not_present_empty :
    encode sampleAbsentCorrection ≠ encode samplePresentEmptyCorrection ∧
    decode (encode samplePresentEmptyCorrection) = some samplePresentEmptyCorrection := by
  decide

/-- The encoder has one deterministic canonical byte-like image for the sample. -/
theorem canonical_encoding_is_fixed :
    encode sampleAbsentCorrection =
      [76, 79, 65, 77, 1,
       1, 2, 10, 11,
       2, 2, 20, 21,
       3, 1, 30] := by
  decide

private def truncatedPayload : List Nat :=
  magic ++ [1, 3, 10]

private def unknownSection : List Nat :=
  magic ++ [99, 0]

private def duplicateEventSection : List Nat :=
  magic ++
    encodeSection .events [10] ++
    encodeSection .events [11] ++
    encodeSection .validity [20] ++
    encodeSection .descriptions [30]

private def missingDescriptionSection : List Nat :=
  magic ++
    encodeSection .events [10] ++
    encodeSection .validity [20]

private def reorderedRequiredSections : List Nat :=
  magic ++
    encodeSection .validity [20] ++
    encodeSection .events [10] ++
    encodeSection .descriptions [30]

private def wrongVersion : List Nat := [76, 79, 65, 77, 2]

/-- Declared payload length larger than remaining input is rejected. -/
theorem truncated_payload_refused :
    decode truncatedPayload = none := by
  decide

/-- Unknown section tags fail closed under this wire version. -/
theorem unknown_section_refused :
    decode unknownSection = none := by
  decide

/-- Duplicate required facet sections are not silently merged or last-write-wins. -/
theorem duplicate_section_refused :
    decode duplicateEventSection = none := by
  decide

/-- Missing required facet sections are rejected. -/
theorem missing_required_section_refused :
    decode missingDescriptionSection = none := by
  decide

/-- Canonical section ordering is part of the deterministic framing. -/
theorem reordered_sections_refused :
    decode reorderedRequiredSections = none := by
  decide

/-- Unknown wire version/header is rejected rather than guessed. -/
theorem wrong_version_refused :
    decode wrongVersion = none := by
  decide

private def projection (actual : SyntheticActual) : Nat × Nat × Nat × Option Nat :=
  ( actual.events.length,
    actual.validity.length,
    actual.descriptions.length,
    actual.corrections.map List.length )

/-- Decode after canonical encode preserves a representative derived projection. -/
theorem projection_parity_after_roundtrip :
    match decode (encode samplePresentCorrection) with
    | some decoded => projection decoded = projection samplePresentCorrection
    | none => False := by
  decide

end Loam.Observation152
