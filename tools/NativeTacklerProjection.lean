import Loam.Authority.ActualAuthority
import Loam.Review.ActualJournalProjection
import Loam.Review.ScheduledReview
import Loam.Tests.Support

namespace Loam.Tools.NativeTacklerProjection

open Loam.Core
open Loam.Tests.Support

set_option autoImplicit false

/-!
Read-only exporter of a disposable, constrained Actual journal read model.

Input is one existing qualified HouseholdImage test root. It never writes
the household itself. The output TSV is internal test transport, NOT a new
canonical LOAM format, and will be converted to Tackler txn read models.
-/

private def emit (root : System.FilePath) (output : System.FilePath) : IO Unit := do
  let observed ← requireOk (← Loam.ActualAuthority.loadHouseholdObserved? root)
    "native Actual authority"
  let scheduled ← requireOk
    (Loam.ScheduledReview.fromGenerationForEvents observed.generation
      observed.image.evidence.events) "same-generation Scheduled evidence"
  let openRecords ← requireOk
    (Loam.ScheduledReview.currentOpenRecords scheduled) "open Scheduled frontier"
  let openIds := openRecords.map (fun row => row.id.token)
  expect (!openIds.contains "paid" && !openIds.contains "cancelled" &&
          openIds.contains "first" && openIds.contains "exception")
    "native Scheduled completion/exception changed"

  let entries ← requireOk
    (Loam.ActualJournalProjection.fromImage? observed.image)
    "current correction-aware journal projection"
  let mut lines : Array String := #["LOAM-NATIVE-TACKLER-READ-MODEL\t1"]
  for entry in entries do
    let id := entry.event.id.token
    let date := entry.validOn
    if id.contains '\t' || id.contains '\n' || date.contains '\t' ||
       date.contains '\n' || date.length != 10 then
      throw (IO.userError "unsafe read-model event identity or date")
    lines := lines.push s!"T\t{date}\t{id}"
    if entry.event.effects.isEmpty then
      throw (IO.userError "PTA read model cannot represent an effect-free Event")
    for effect in entry.event.effects do
      lines := lines.push
        s!"P\t{effect.locus.token}\t{effect.measure.token}\t{effect.quantity.quanta}"
    lines := lines.push "END"
  IO.FS.writeFile output (String.intercalate "\n" lines.toList ++ "\n")
  IO.println s!"NATIVE_TACKLER_READ_MODEL_PASS current_events={entries.length} open_scheduled={openRecords.length}"

def run (args : List String) : IO Unit := do
  match args with
  | [root, output] => emit (System.FilePath.mk root) (System.FilePath.mk output)
  | _ => throw (IO.userError "usage: NativeTacklerProjection HOUSEHOLD_ROOT OUTPUT_TSV")

end Loam.Tools.NativeTacklerProjection

def main (args : List String) : IO Unit :=
  Loam.Tools.NativeTacklerProjection.run args
