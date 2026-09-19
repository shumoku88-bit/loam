import Loam.ActualAuthority
import Loam.Cli.EffectiveCli

open Loam
open Loam.ActualAuthority

private def expect (condition : Bool) (message : String) : IO Unit := do
  unless condition do
    throw <| IO.userError message

private def validWire : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++
  "TX\tev-1\t2026-09-01\tNODESC\n" ++
  "EFFECT\twallet\tjpy\t-100\n" ++
  "EFFECT\tbank\tjpy\t100\n" ++
  "ENDTX\n"

private def unknownRowWire : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++     -- line 1
  "TX\tev-1\t2026-09-01\tNODESC\n" ++   -- line 2
  "FOOBAR\tsomething\n" ++              -- line 3
  "ENDTX\n"

private def malformedQuantaWire : String :=
  "LOAM-NORMALIZED-ACTUAL\t1\n" ++     -- line 1
  "TX\tev-1\t2026-09-01\tNODESC\n" ++   -- line 2
  "EFFECT\twallet\tjpy\tnot-a-number\n" ++ -- line 3
  "ENDTX\n"

def main : IO Unit := do
  let tempDir ← IO.FS.createTempDir
  let actualPath := tempDir / "actual.loam"

  -- 1. valid actual.loam は新しい詳細loaderでも正常にloadできる
  IO.FS.writeFile actualPath validWire
  let imageResult ← loadImageFileDetailed actualPath
  match imageResult with
  | .ok image =>
      expect ((image.currentEvents.findById? ⟨"ev-1"⟩).isSome)
        "1a. expected event ev-1 in loaded image"
  | .error err =>
      throw <| IO.userError s!"1b. expected valid wire to load, got error: {err}"

  let evidenceResult ← loadActualFileDetailed actualPath
  match evidenceResult with
  | .ok ev =>
      expect ((ev.events.findById? ⟨"ev-1"⟩).isSome)
        "1c. expected event ev-1 in loaded evidence"
  | .error err =>
      throw <| IO.userError s!"1d. expected valid wire to load evidence, got error: {err}"

  -- 2. malformed wire では NormalizedActualDecodeError が保持される
  IO.FS.writeFile actualPath unknownRowWire
  let unknownResult ← loadImageFileDetailed actualPath
  match unknownResult with
  | .error (.decode _ (.parse { line := 3, reason := .unknownRowType "FOOBAR" })) => pure ()
  | .error err =>
      throw <| IO.userError s!"2a. expected unknownRowType at line 3, got: {err}"
  | .ok _ =>
      throw <| IO.userError "2b. expected unknownRowWire to fail, but succeeded"

  -- 3. parse error の line number が ActualAuthority 境界を越えても保持される
  IO.FS.writeFile actualPath malformedQuantaWire
  let quantaResult ← loadImageFileDetailed actualPath
  match quantaResult with
  | .error (.decode _ (.parse { line := 3, reason := .invalidInteger "not-a-number" })) => pure ()
  | .error err =>
      throw <| IO.userError s!"3a. expected invalidInteger at line 3, got: {err}"
  | .ok _ =>
      throw <| IO.userError "3b. expected malformedQuantaWire to fail, but succeeded"

  -- 4. 選んだ user-facing boundary で reason が表示される (message 出力と CLI 終了コード)
  let loadErr := LoadError.decode actualPath (.parse { line := 3, reason := .invalidInteger "not-a-number" })
  let msg := loadErr.message
  expect (msg.contains "line 3: invalid integer quantity: 'not-a-number'")
    s!"4a. expected message to contain line 3 diagnostic, got: {msg}"
  expect (msg.contains s!"failed to load Actual: {actualPath}")
    s!"4b. expected message to contain file path header, got: {msg}"

  -- EffectiveCli.showEffectiveQuantities が exit code 2 を返すことを確認
  let cliExit ← Loam.EffectiveCli.showEffectiveQuantities actualPath.toString
  expect (cliExit == 2)
    s!"4c. expected showEffectiveQuantities to exit with code 2, got {cliExit}"

  -- 5. legacy loadActual? / loadImageFile? は従来どおり failure を返す
  let legacyImageResult ← loadImageFile? actualPath
  match legacyImageResult with
  | .error legacyMsg =>
      expect (legacyMsg == s!"loam: actual authority is malformed or unsupported: {actualPath}")
        s!"5a. legacy error message mismatch, got: {legacyMsg}"
  | .ok _ =>
      throw <| IO.userError "5b. expected legacy loadImageFile? to fail"

  let legacyActualResult ← loadActualFile? actualPath
  match legacyActualResult with
  | .error legacyMsg =>
      expect (legacyMsg == s!"loam: actual authority is malformed or unsupported: {actualPath}")
        s!"5c. legacy error message mismatch, got: {legacyMsg}"
  | .ok _ =>
      throw <| IO.userError "5d. expected legacy loadActualFile? to fail"

  -- 5e. ファイル不在時の legacy エラー確認
  let nonExistent := tempDir / "does-not-exist.loam"
  match ← loadImageFile? nonExistent with
  | .error legacyMsg =>
      expect (legacyMsg == s!"loam: actual authority not found: {nonExistent}")
        s!"5e. legacy not-found message mismatch, got: {legacyMsg}"
  | .ok _ =>
      throw <| IO.userError "5f. expected not-found error"

  -- 6. invalid input による load failure で canonical data は変更されない
  let contentAfterFail ← IO.FS.readFile actualPath
  expect (contentAfterFail == malformedQuantaWire)
    "6. file contents were altered during failed load"

  IO.println "All ActualAuthorityDetailed tests passed successfully!"
