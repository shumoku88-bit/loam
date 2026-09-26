import Loam.BoundedHistorySupport
import Loam.Persistence.SiblingStage
import Loam.Persistence.TokenSyntax
import Loam.Persistence.VersionedRows

namespace Loam.Persistence

open Loam.Core

set_option autoImplicit false

/-!
# Bounded historical support persistence

One replaceable image stores only explicit coordinate/start-day claims.
Missing evidence means no bounded historical claim. Row order has no semantic
priority.
-/

def boundedHistorySupportHeader : String := "LOAM-BOUNDED-HISTORY-SUPPORT\t1"

private def encodeSupportRow?
    (support : Loam.BoundedHistorySupport.Support) : Option String :=
  let locus := support.coordinate.locus.token
  let measure := support.coordinate.measure.token
  if validToken locus && validToken measure then
    some ("SUPPORT\t" ++ locus ++ "\t" ++ measure ++ "\t" ++ support.startDay)
  else
    none

def encodeBoundedHistorySupport?
    (evidence : Loam.BoundedHistorySupport.Evidence) : Option String := do
  let rows ← evidence.supports.mapM encodeSupportRow?
  pure (encodeVersionedRows boundedHistorySupportHeader rows)

private def decodeSupportRow? (row : String) : Option Loam.BoundedHistorySupport.Support :=
  match row.splitOn "\t" with
  | ["SUPPORT", locusToken, measureToken, startDay] =>
      if validToken locusToken && validToken measureToken then
        some {
          coordinate := ⟨⟨locusToken⟩, ⟨measureToken⟩⟩
          startDay := startDay
        }
      else
        none
  | _ => none

def decodeBoundedHistorySupport?
    (input : String) : Option Loam.BoundedHistorySupport.Evidence := do
  let rows ← decodeVersionedRows? boundedHistorySupportHeader input
  let supports ← rows.mapM decodeSupportRow?
  Loam.BoundedHistorySupport.Evidence.ofSupports? supports

def saveBoundedHistorySupport?
    (path : System.FilePath)
    (evidence : Loam.BoundedHistorySupport.Evidence) : IO Bool := do
  match encodeBoundedHistorySupport? evidence with
  | none => return false
  | some text =>
      replaceTextViaSiblingStage path text
      return true

def loadBoundedHistorySupport?
    (path : System.FilePath) : IO (Option Loam.BoundedHistorySupport.Evidence) := do
  let input ← IO.FS.readFile path
  return decodeBoundedHistorySupport? input

end Loam.Persistence
