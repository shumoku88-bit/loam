import Loam.Persistence.HouseholdImagePersistence
import Loam.Tests.Support

namespace Loam.Tests.HouseholdImagePersistence

open Loam.Persistence.HouseholdImage

open Loam.Tests.Support

set_option autoImplicit false

def main : IO Unit := do
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
    "HouseholdImage persistence: order, opaque bytes, unknown sections, and absent != present-empty passed."

end Loam.Tests.HouseholdImagePersistence

def main : IO Unit :=
  Loam.Tests.HouseholdImagePersistence.main
