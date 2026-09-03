import Loam.Core.EventDescription
import Loam.Persistence.EventDescriptionPersistence

open Loam.Core
open Loam.Persistence

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

def main : IO Unit := do
  -- 1. Empty memory wire shape and round-trip
  let emptyMem := EventDescriptionMemory.empty
  let emptyWire? := encodeEventDescriptionMemory? emptyMem
  expect (emptyWire? == some "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n")
    "Empty EventDescriptionMemory did not produce expected header-only wire"

  match decodeEventDescriptionMemory? "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" with
  | some m => expect m.entries.isEmpty "Empty EventDescriptionMemory decoded with non-empty entries"
  | none => throw <| IO.userError "Empty EventDescriptionMemory failed to decode"

  -- 2. Real historical actual text samples
  let sample1 : EventDescription := { event := ⟨"ev-1"⟩, text := "コンビニ" }
  let sample2 : EventDescription := { event := ⟨"ev-2"⟩, text := "smbc→paypay" }
  let sample3 : EventDescription := { event := ⟨"ev-3"⟩, text := "移動smbc->ゆうちょ" }
  let sample4 : EventDescription := { event := ⟨"ev-4"⟩, text := "健康保険料(6月分)" }
  let sample5 : EventDescription := { event := ⟨"ev-5"⟩, text := "ダイソー、マイクロファイバー" }
  let sample6 : EventDescription := { event := ⟨"ev-6"⟩, text := "Opening Balance" }
  let sample7 : EventDescription := { event := ⟨"ev-7"⟩, text := "借金開始残高（2026-06-19確認残高から返済2件を復元）" }

  let realEntries := [sample1, sample2, sample3, sample4, sample5, sample6, sample7]
  let realMem ← match EventDescriptionMemory.ofEntries? realEntries with
    | some m => pure m
    | none => throw <| IO.userError "Failed to construct EventDescriptionMemory from real samples"

  let realEncoded ← match encodeEventDescriptionMemory? realMem with
    | some s => pure s
    | none => throw <| IO.userError "Failed to encode real samples"

  match decodeEventDescriptionMemory? realEncoded with
  | some m => expect (m.entries == realEntries) "Real samples failed round-trip decode entries match"
  | none => throw <| IO.userError "Real samples failed to decode from encoded wire"

  -- Query test: findText?
  expect (realMem.findText? ⟨"ev-1"⟩ == some "コンビニ") "findText? ev-1 failed"
  expect (realMem.findText? ⟨"ev-2"⟩ == some "smbc→paypay") "findText? ev-2 failed"
  expect (realMem.findText? ⟨"ev-7"⟩ == some "借金開始残高（2026-06-19確認残高から返済2件を復元）") "findText? ev-7 failed"
  expect (realMem.findText? ⟨"ev-missing"⟩ == none) "findText? on missing ID returned non-none"

  -- 3. Synthetic edge cases: escapes, Unicode, whitespace, empty string
  let edge1 : EventDescription := { event := ⟨"edge-tab"⟩, text := "tab\there" }
  let edge2 : EventDescription := { event := ⟨"edge-newline"⟩, text := "line1\nline2" }
  let edge3 : EventDescription := { event := ⟨"edge-cr"⟩, text := "cr\rhere" }
  let edge4 : EventDescription := { event := ⟨"edge-backslash"⟩, text := "back\\slash and \\\\ double" }
  let edge5 : EventDescription := { event := ⟨"edge-combo"⟩, text := "combo: \\t \\n \\r \\\\ all in one" }
  let edge6 : EventDescription := { event := ⟨"edge-spaces"⟩, text := "   spaces leading and trailing   " }
  let edge7 : EventDescription := { event := ⟨"edge-empty"⟩, text := "" }
  let edge8 : EventDescription := { event := ⟨"edge-unicode"⟩, text := "☕ 🥐 🚀 漢字 カタカナ ひらがな English" }

  let edgeEntries := [edge1, edge2, edge3, edge4, edge5, edge6, edge7, edge8]
  let edgeMem ← match EventDescriptionMemory.ofEntries? edgeEntries with
    | some m => pure m
    | none => throw <| IO.userError "Failed to construct edgeMem"

  let edgeEncoded ← match encodeEventDescriptionMemory? edgeMem with
    | some s => pure s
    | none => throw <| IO.userError "Failed to encode edgeMem"

  match decodeEventDescriptionMemory? edgeEncoded with
  | some m => expect (m.entries == edgeEntries) "Edge cases failed exact round trip entries match"
  | none => throw <| IO.userError "Edge cases failed to decode from encoded wire"

  -- Verify escaped text format manually
  expect (escapeText "a\tb\nc\rd\\e" == "a\\tb\\nc\\rd\\\\e") "escapeText mapping incorrect"
  expect (unescapeText? "a\\tb\\nc\\rd\\\\e" == some "a\tb\nc\rd\\e") "unescapeText? mapping incorrect"

  -- 4. Fail-closed persistence invariants
  -- Invariant 4.1: duplicate EventId in wire format
  let dupWire := "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
                 "DESC\tsame-event\tFirst text\n" ++
                 "DESC\tsame-event\tSecond text\n"
  expect (decodeEventDescriptionMemory? dupWire).isNone
    "Failed closed: Duplicate EventId was admitted"

  -- Invariant 4.2: malformed row prefix
  let badPrefixWire := "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
                       "NOTE\tev-1\tText\n"
  expect (decodeEventDescriptionMemory? badPrefixWire).isNone
    "Failed closed: Malformed row prefix NOTE was admitted"

  -- Invariant 4.3: malformed row column count
  let badColWire := "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
                    "DESC\tev-1\n"
  expect (decodeEventDescriptionMemory? badColWire).isNone
    "Failed closed: Row with missing text column was admitted"

  -- Invariant 4.4: malformed escape sequences
  let badEscapeWire1 := "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
                        "DESC\tev-1\tInvalid \\x escape\n"
  expect (decodeEventDescriptionMemory? badEscapeWire1).isNone
    "Failed closed: Invalid escape sequence \\x was admitted"

  let badEscapeWire2 := "LOAM-EVENT-DESCRIPTION-MEMORY\t1\n" ++
                        "DESC\tev-1\tTrailing backslash \\\n"
  expect (decodeEventDescriptionMemory? badEscapeWire2).isNone
    "Failed closed: Trailing backslash was admitted"

  -- Invariant 4.5: wrong header or unsupported version
  expect (decodeEventDescriptionMemory? "LOAM-EVENT-DESCRIPTION-MEMORY\t2\nDESC\tev-1\tText\n").isNone
    "Failed closed: Version 2 was admitted"
  expect (decodeEventDescriptionMemory? "WRONG-HEADER\t1\nDESC\tev-1\tText\n").isNone
    "Failed closed: Wrong header was admitted"

  -- Invariant 4.6: missing trailing newline
  expect (decodeEventDescriptionMemory? "LOAM-EVENT-DESCRIPTION-MEMORY\t1\nDESC\tev-1\tText").isNone
    "Failed closed: Missing trailing newline was admitted"

  -- Invariant 4.7: invalid EventId token containing tab or newline
  let badTokenWire1 := "LOAM-EVENT-DESCRIPTION-MEMORY\t1\nDESC\t\tText\n"
  expect (decodeEventDescriptionMemory? badTokenWire1).isNone
    "Failed closed: Empty EventId was admitted"

  let badTokenDesc : EventDescription := { event := ⟨"bad\tid"⟩, text := "Text" }
  let badTokenMem : EventDescriptionMemory := { entries := [badTokenDesc], eventNodup := by simp }
  expect (encodeEventDescriptionMemory? badTokenMem).isNone
    "Failed closed: Token containing tab was encoded"

  -- 5. IO filesystem round-trip
  let tmpDir := System.FilePath.mk "scratch/test-event-description"
  IO.FS.createDirAll tmpDir
  let tmpFile := tmpDir / "memory.descriptions"

  let saveOk ← saveEventDescriptionMemory? tmpFile realMem
  expect saveOk "Failed to save EventDescriptionMemory to disk"

  let loadedMem ← match ← loadEventDescriptionMemory? tmpFile with
    | some m => pure m
    | none => throw <| IO.userError "Failed to load saved EventDescriptionMemory from disk"
  expect (loadedMem.entries == realMem.entries)
    "Loaded EventDescriptionMemory from disk does not match saved memory"

  -- Cleanup tmp
  IO.FS.removeFile tmpFile
  IO.FS.removeDirAll tmpDir

  IO.println "All EventDescription persistence tests passed."
