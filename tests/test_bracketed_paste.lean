import Loam.Tui.Kernel
import Loam.Tui.Terminal
import Loam.Tui.Main
import Loam.Tui.ActualWorkspace

open Loam.Tui.Terminal

def makeBytes (s : String) : ByteArray :=
  s.toUTF8

def testSingleLinePaste : IO Unit := do
  if singleLinePaste "simple" != "simple" then
    throw (IO.userError "singleLinePaste failed on simple string")
  if singleLinePaste "2026-10-03\n" != "2026-10-03" then
    throw (IO.userError "singleLinePaste failed to strip trailing LF")
  if singleLinePaste "2026-10-03\r\n" != "2026-10-03" then
    throw (IO.userError "singleLinePaste failed to strip trailing CRLF")
  if singleLinePaste "first line\nsecond line" != "first line" then
    throw (IO.userError "singleLinePaste failed on multiline")
  if singleLinePaste "  padded  \nother" != "  padded" then
    throw (IO.userError "singleLinePaste failed to preserve leading and strip trailing")

def testNormalizePasteText : IO Unit := do
  let input := "line1\r\nline2\rline3\n"
  let expected := "line1\nline2\nline3\n"
  if normalizePasteText input != expected then
    throw (IO.userError s!"normalizePasteText failed: got {repr (normalizePasteText input)}")

def testParseBracketedPasteBasic : IO Unit := do
  resetInputBuffer
  let packet := "\x1b[200~grocery store\x1b[201~"
  inputBufferRef.set { data := makeBytes packet, pos := 0 }
  let key ← readKey
  match key with
  | .paste text =>
      if text != "grocery store" then
        throw (IO.userError s!"Expected 'grocery store', got '{text}'")
  | k => throw (IO.userError s!"Expected Key.paste, got {repr k}")

def testParseBracketedPasteUtf8 : IO Unit := do
  resetInputBuffer
  let packet := "\x1b[200~2026年10月03日 スーパー決済\x1b[201~"
  inputBufferRef.set { data := makeBytes packet, pos := 0 }
  let key ← readKey
  match key with
  | .paste text =>
      if text != "2026年10月03日 スーパー決済" then
        throw (IO.userError s!"Expected UTF-8 Japanese text, got '{text}'")
  | k => throw (IO.userError s!"Expected Key.paste, got {repr k}")

def testParseBracketedPasteFollowedByKey : IO Unit := do
  resetInputBuffer
  -- Paste followed immediately by an Enter key (\r)
  let packet := "\x1b[200~15000\x1b[201~\r"
  inputBufferRef.set { data := makeBytes packet, pos := 0 }
  let key1 ← readKey
  match key1 with
  | .paste text =>
      if text != "15000" then
        throw (IO.userError s!"Expected '15000', got '{text}'")
  | k => throw (IO.userError s!"Expected Key.paste, got {repr k}")
  let key2 ← readKey
  if key2 != Key.enter then
    throw (IO.userError s!"Expected Key.enter after paste, got {repr key2}")

def testActualWorkspaceSearchPaste : IO Unit := do
  let snapshot : Loam.Tui.Main.Snapshot := {
    actual := {
      today := "2026-10-03"
      allRecords := []
    }
    scheduled := .error "none"
  }
  let initial := Loam.Tui.ActualWorkspace.initial "2026-10-03"
  let searchState := { initial with searchEditing := true, searchQuery := "" }

  -- Paste into search query
  let step := Loam.Tui.ActualWorkspace.update snapshot searchState (.searchPaste "coffee\n")
  if step.state.searchQuery != "coffee" then
    throw (IO.userError s!"Expected searchQuery 'coffee', got '{step.state.searchQuery}'")

  -- Paste additional text
  let step2 := Loam.Tui.ActualWorkspace.update snapshot step.state (.searchPaste " beans")
  if step2.state.searchQuery != "coffee beans" then
    throw (IO.userError s!"Expected searchQuery 'coffee beans', got '{step2.state.searchQuery}'")

def main : IO Unit := do
  testSingleLinePaste
  testNormalizePasteText
  testParseBracketedPasteBasic
  testParseBracketedPasteUtf8
  testParseBracketedPasteFollowedByKey
  testActualWorkspaceSearchPaste
  IO.println "All bracketed paste tests passed."
