import Loam.Persistence.HouseholdImagePersistence
import Loam.Tests.Support

namespace Loam.Tests.HouseholdImagePersistence

open Loam.Persistence.HouseholdImage

open Loam.Tests.Support

set_option autoImplicit false

/-- Pre-slice decoder, retained only as a bounded acceptance/opaque-byte oracle. -/
private def referenceSection? (input : String) : Option (Section × String) := do
  let (line, rest) ← match input.splitOn "\n" with
    | line :: next :: rest => some (line, String.intercalate "\n" (next :: rest))
    | _ => none
  match line.splitOn "\t" with
  | ["SECTION", name, lengthText] =>
      if name.isEmpty || name.contains '\t' || name.contains '\n' || name.contains '\r' then none
      else do
        let count ← lengthText.toNat?
        if rest.length < count then none
        else some ({ name, body := (rest.take count).toString }, (rest.drop count).toString)
  | _ => none

private def referenceSections? : Nat → String → List Section → Option (List Section)
  | 0, _, _ => none
  | fuel + 1, input, acc => do
      if input.isEmpty then return acc.reverse
      let (part, remaining) ← referenceSection? input
      if acc.any (fun existing => existing.name == part.name) then none
      else referenceSections? fuel remaining (part :: acc)

private def referenceDecode? (input : String) : Option Image := do
  let headerPrefix := header ++ "\n"
  if !input.startsWith headerPrefix then none
  else
    let rest := (input.drop headerPrefix.length).toString
    let sections ← referenceSections? (rest.length + 1) rest []
    some { sections }

private def checkParity (wire : String) : IO Unit := do
  expect (decode? wire == referenceDecode? wire)
    "slice decoder changed acceptance, section order or opaque body characters"

private def checkFramingCorpus : IO Unit := do
  for name in ["Actual", "Tail", "日本語😀", "", "bad\tname", "bad\rname"] do
    for length in ["0", "1", "2", "4", "0002", "999", "-1", "+2", "0x2", "oops", ""] do
      for body in ["", "ab", "é😀", "漢字\nx", "\nSECTION\tFake\t0\n", "abc\n"] do
        for tail in ["", "SECTION\tTail\t0\n", "\n"] do
          checkParity (header ++ "\nSECTION\t" ++ name ++ "\t" ++ length ++ "\n" ++ body ++ tail)
  for body in ["", "no final newline", "é😀\r\nSECTION\tFake\t99\n"] do
    let image : Image := { sections := [
      { name := "First", body := "" }, { name := "Unknown", body },
      { name := "Actual", body := "opaque" }, { name := "Last", body := "" } ] }
    for sections in [image.sections, image.sections.reverse] do
      let wire ← requireSome (encode? { sections }) "framing corpus encode"
      checkParity wire
      for n in List.range (wire.length + 1) do
        checkParity (wire.take n).toString
  expect (decode? (header ++ "\nSECTION\tUnicode\t2\né😀")).isSome
    "outer lengths ceased to count Unicode code points"
  expect (decode? (header ++ "\nSECTION\tUnicode\t6\né😀")).isNone
    "outer lengths silently changed to UTF-8 bytes"

def main : IO Unit := do
  checkFramingCorpus
  let base : Image := {
    sections := [
      { name := "Actual", body := "LOAM-NORMALIZED-ACTUAL\t4\n" },
      { name := "Attention", body := "LOAM-ATTENTION-MEMORY\t1\n" },
      { name := "Securities", body := "future\tpayload\n二行目\n" }
    ]
  }

  let wire ← requireSome (encode? base) "valid HouseholdImage did not encode"
  let decoded ← requireSome (decode? wire) "encoded HouseholdImage did not decode"
  expect (decoded == base) "HouseholdImage round-trip changed section order or bytes"

  expect (contains decoded "Actual") "present Actual section disappeared"
  expect (!(contains decoded "Capacity")) "absent Capacity section was invented"
  expect (body? decoded "Capacity" == none)
    "absent Capacity section did not remain absent"
  expect (body? decoded "Securities" == some "future\tpayload\n二行目\n")
    "unknown future section did not survive exactly"

  let withEmpty ← requireSome
    (appendSection? decoded { name := "Capacity", body := "" })
    "explicit empty Capacity section could not be appended"
  expect (contains withEmpty "Capacity")
    "explicit empty Capacity section lost physical presence"
  expect (body? withEmpty "Capacity" == some "")
    "present-empty Capacity collapsed into section absence"

  let withEmptyWire ← requireSome
    (encode? withEmpty)
    "HouseholdImage containing present-empty section did not encode"
  let withEmptyDecoded ← requireSome
    (decode? withEmptyWire)
    "HouseholdImage containing present-empty section did not decode"
  expect (body? withEmptyDecoded "Capacity" == some "")
    "present-empty section did not survive the wire format"

  let changedAttention := "LOAM-ATTENTION-MEMORY\t1\nITEM\ta\tNO_DUE_DATE\t-\twatch\n"
  let rewritten ← requireSome
    (replaceBody? withEmptyDecoded "Attention" changedAttention)
    "present Attention section could not be replaced"
  expect (body? rewritten "Attention" == some changedAttention)
    "Attention replacement did not install exact bytes"
  expect (body? rewritten "Securities" == body? withEmptyDecoded "Securities")
    "Attention replacement changed unknown future evidence"
  expect (body? rewritten "Capacity" == some "")
    "Attention replacement changed present-empty evidence"
  expect
    (rewritten.sections.map (fun part => part.name) ==
      withEmptyDecoded.sections.map (fun part => part.name))
    "Attention replacement changed section ordering"

  expect (replaceBody? rewritten "Missing" "invented").isNone
    "replaceBody invented a previously absent section"

  expect
    (appendSection? rewritten { name := "Actual", body := "duplicate" }).isNone
    "duplicate section identity was accepted"
  expect
    (appendSection? rewritten { name := "unsafe\tname", body := "x" }).isNone
    "unsafe section identity was accepted"

  let duplicate : Image := {
    sections := rewritten.sections ++ [{ name := "Actual", body := "duplicate" }]
  }
  expect (encode? duplicate).isNone "duplicate section identity was encodable"

  let truncated := (wire.dropEnd 1).toString
  expect (decode? truncated).isNone "truncated HouseholdImage was accepted"

  let unknownVersion :=
    "LOAM-HOUSEHOLD-IMAGE\t999\n" ++
      (wire.drop (header.length + 1)).toString
  expect (decode? unknownVersion).isNone "unknown HouseholdImage version was accepted"

  let emptyImage : Image := { sections := [] }
  let emptyWire ← requireSome (encode? emptyImage) "empty outer image did not encode"
  let emptyDecoded ← requireSome (decode? emptyWire) "empty outer image did not decode"
  expect (emptyDecoded == emptyImage)
    "empty outer image did not preserve complete section absence"

  IO.println
    "HouseholdImage persistence: slice/list acceptance parity, Unicode framing, order, opaque bytes, unknown sections, and absent != present-empty passed."

end Loam.Tests.HouseholdImagePersistence

def main : IO Unit :=
  Loam.Tests.HouseholdImagePersistence.main
