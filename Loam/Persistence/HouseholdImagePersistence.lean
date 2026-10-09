import Std

namespace Loam.Persistence.HouseholdImage

set_option autoImplicit false

/-!
# Household image outer persistence

This module owns only the physical outer framing for one future household
generation.

It deliberately does not know the semantics of Actual, Scheduled, Capacity, or
any other inner family. Section bodies remain opaque canonical text owned by
their existing codecs.

The version remains `2` because the research sequence used version 1 for a
fixed thirteen-section envelope and qualified the extensible named-section
framing as version 2. Version 1 never became production authority.
-/

/-- One opaque named payload inside a household generation. -/
structure Section where
  name : String
  body : String
deriving Repr, BEq

/--
One ordered collection of named opaque payloads.

Section absence is meaningful. An absent section is not normalized into an
explicit empty body.
-/
structure Image where
  sections : List Section
deriving Repr, BEq

def header : String := "LOAM-HOUSEHOLD-IMAGE\t2"

private def validSectionName (name : String) : Bool :=
  !name.isEmpty &&
    !name.contains '\t' &&
    !name.contains '\n' &&
    !name.contains '\r'

private def uniqueSectionNames : List Section → Bool
  | [] => true
  | part :: rest =>
      !(rest.any fun later => later.name == part.name) &&
        uniqueSectionNames rest

private def encodeSection (part : Section) : String :=
  "SECTION\t" ++ part.name ++ "\t" ++ toString part.body.length ++
    "\n" ++ part.body

/--
Encode one complete outer image.

Payloads are copied unchanged. Unknown section names are allowed. Duplicate or
syntactically unsafe names are refused so section identity remains unambiguous.
-/
def encode? (image : Image) : Option String := do
  if !uniqueSectionNames image.sections then
    none
  if !(image.sections.all fun part => validSectionName part.name) then
    none
  pure <| header ++ "\n" ++ String.join (image.sections.map encodeSection)

private def takeLine? (input : String.Slice) : Option (String × String.Slice) := do
  let newline ← input.find? '\n'
  some ((input.sliceTo newline).toString, input.sliceFrom (newline.nextn 1))

/-- Advance exactly the declared code-point count; never clamp a truncated body. -/
private def advanceChars? {input : String.Slice} : Nat → input.Pos → Option input.Pos
  | 0, pos => some pos
  | count + 1, pos =>
      if h : pos = input.endPos then none
      else advanceChars? count (pos.next h)

private def takeSection? (input : String.Slice) : Option (Section × String.Slice) := do
  let (line, rest) ← takeLine? input
  match line.splitOn "\t" with
  | ["SECTION", name, lengthText] =>
      if !validSectionName name then
        none
      else do
        let count ← lengthText.toNat?
        -- Lengths remain Unicode code-point counts, not UTF-8 byte counts.
        -- Advance once to the boundary and share the unread suffix as a slice.
        -- Even for a huge malformed declaration, no character count can exceed
        -- the unread byte size. This bound does not redefine the framing unit.
        if count > rest.utf8ByteSize then none
        else do
          let boundary ← advanceChars? count rest.startPos
          let body := rest.sliceTo boundary
          some ({ name := name, body := body.toString }, rest.sliceFrom boundary)
  | _ => none

private def decodeSections? :
    Nat → String.Slice → List Section → Option (List Section)
  | 0, _, _ => none
  | Nat.succ fuel, input, acc =>
      if input.isEmpty then
        some acc.reverse
      else do
        let (part, remaining) ← takeSection? input
        if acc.any (fun existing => existing.name == part.name) then
          none
        else
          decodeSections? fuel remaining (part :: acc)

/--
Decode one version-2 household image.

No currently known semantic family is required here. In particular, missing
sections survive as missing instead of being invented as empty evidence.
-/
def decode? (input : String) : Option Image := do
  let headerPrefix := header ++ "\n"
  if !input.startsWith headerPrefix then
    none
  else
    let rest := input.drop headerPrefix.length
    -- Each accepted section consumes a nonempty framing line. Byte size is an
    -- O(1) upper bound on their count; it does not interpret payload lengths.
    let sections ← decodeSections? (input.utf8ByteSize + 1) rest []
    some { sections := sections }

/-- Return whether one section identity is physically present. -/
def contains (image : Image) (name : String) : Bool :=
  image.sections.any fun part => part.name == name

/--
Return one opaque section body.

`none` means the section is absent. `some ""` means it is explicitly present
with an empty payload. This distinction is required for legacy migration.
-/
def body? (image : Image) (name : String) : Option String :=
  match image.sections.find? (fun part => part.name == name) with
  | some part => some part.body
  | none => none

/--
Replace one physically present payload without interpreting or reconstructing
any other section. Section order and all untouched bytes are preserved.
-/
def replaceBody? (image : Image) (name body : String) : Option Image :=
  if !(contains image name) then
    none
  else
    some {
      sections := image.sections.map fun part =>
        if part.name == name then { part with body := body } else part
    }

/--
Append one new physically present section.

This is the operation a migration adapter can use for each legacy file that
actually exists. Missing legacy files simply do not call this function.
-/
def appendSection? (image : Image) (part : Section) : Option Image :=
  if !validSectionName part.name || contains image part.name then
    none
  else
    some { sections := image.sections ++ [part] }

end Loam.Persistence.HouseholdImage
