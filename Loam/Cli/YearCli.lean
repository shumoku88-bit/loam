import Loam.HouseholdPaths
import Loam.ActualDate
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.WriterOwnership
import Loam.Authority.ActualAuthority
import Loam.Review.ActualJournalProjection
import Loam.Persistence.TextEscape

namespace Loam.YearCli

open Loam.Core

set_option autoImplicit false

/-!
Read current-effective dated Actual records for one chosen calendar year.
The ordinary installed HouseholdImage remains the source until a separate
journal/YYYY/household.loam exists. This command never publishes or creates
household facts; an older saved generation need not know later corrections.
-/

def validYear (year : String) : Bool :=
  year.length == 4 && year.toNat?.isSome && year != "0000"

structure Report where
  sourceRoot : System.FilePath
  sourceFile : System.FilePath
  entries : List Loam.ActualJournalProjection.Entry

/-- Existing NormalizedActual codec, not a new annual wire format. -/
def extractedActualPath (root : System.FilePath) (year : String) : System.FilePath :=
  Loam.HouseholdPaths.yearRoot root year / "actual-year.loam"

def readYear (root : System.FilePath) (year : String) :
    IO (Except String Report) := do
  if !validYear year then
    return .error "loam: year must be a four-digit calendar year (YYYY)"
  let archiveRoot := Loam.HouseholdPaths.yearRoot root year
  let archivePresent ← archiveRoot.pathExists
  let checkpoint := Loam.HouseholdAuthority.path archiveRoot
  let extracted := extractedActualPath root year
  let checkpointPresent ← checkpoint.pathExists
  let extractedPresent ← extracted.pathExists
  if archivePresent && !checkpointPresent && !extractedPresent then
    return .error s!"loam: saved year {year} exists but its authority is missing"
  if checkpointPresent && extractedPresent then
    return .error s!"loam: year {year} has ambiguous archive sources"
  let sourceRoot := if archivePresent then archiveRoot else root
  let sourceFile :=
    if checkpointPresent then checkpoint
    else if extractedPresent then extracted
    else Loam.HouseholdAuthority.path root
  let actual ←
    match ← Loam.ActualAuthority.loadImageFile? sourceFile with
    | .ok image => pure image
    | .error message => return .error message
  let entries ←
    match Loam.ActualJournalProjection.fromImage? actual with
    | .ok rows => pure rows
    | .error message => return .error message
  let dated := entries.filter fun entry => entry.validOn.startsWith (year ++ "-")
  if !archivePresent && dated.isEmpty then
    -- Legacy single-file households have no declared start year. The
    -- currently observed year may legitimately be empty, but an arbitrary
    -- older/future year with no dated evidence is unavailable, NOT zero.
    let observedDay? ← Loam.ActualDate.todayIso?
    if !(observedDay?.any fun day => day.startsWith (year ++ "-")) then
      return .error s!"loam: year {year} has no saved source or recorded Actual"
  return .ok {
    sourceRoot := sourceRoot
    sourceFile := sourceFile
    entries := dated
  }

/--
Create one immutable **as-of** checkpoint for an already-ended calendar year
under journal/YYYY/household.loam. This copies the entire qualified source
generation, deliberately preserving unknown sections and every other family's
evidence. It is NOT a bounded annual partition or year-close certification.

No automatic rollover, no new publisher, and no replacement of the installed
canonical root. Once a year directory exists, this command refuses to edit it.
-/
def checkpointYear (root : System.FilePath) (year : String) :
    IO (Except String System.FilePath) := do
  if !validYear year then
    return .error "loam: checkpoint year must be four digits (YYYY)"
  let now? ← Loam.ActualDate.todayIso?
  let some now := now? | return .error "loam: current calendar date is unavailable"
  let activeYear := (now.splitOn "-").head!
  if year >= activeYear then
    return .error "loam: checkpoint requires an already-ended calendar year"
  let archiveRoot := Loam.HouseholdPaths.yearRoot root year
  -- Source and destination paths have distinct writer locks; always take
  -- source ownership first, never open the destination in the reverse order.
  Loam.HouseholdAuthority.withOwnership root do
    if ← archiveRoot.pathExists then
      return .error s!"loam: year {year} destination already exists; no overwrite"
    let generation ←
      match ← Loam.HouseholdAuthority.loadCurrent? root with
      | .ok source => pure source
      | .error message => return .error message
    let actual ←
      match ← Loam.ActualAuthority.loadHouseholdImage? root with
      | .ok source => pure source
      | .error message => return .error message
    let entries ←
      match Loam.ActualJournalProjection.fromImage? actual with
      | .ok entries => pure entries
      | .error message => return .error message
    if !(entries.any fun entry => entry.validOn.startsWith (year ++ "-")) then
      return .error s!"loam: no admitted Actual records for year {year}"
    -- A checkpoint must be an identical qualified generation, not an
    -- independently initialized household or an invented opening balance.
    if Loam.Persistence.HouseholdImage.encode? generation.image !=
        some generation.wire then
      return .error "loam: source HouseholdImage has noncanonical framing"
    -- WriterOwnership's sibling lock is opened before installInitial?
    -- creates its parent. Create this new, previously-absent year directory
    -- explicitly so that existing installation and locking work unchanged.
    try
      IO.FS.createDirAll archiveRoot
    catch error =>
      return .error ("loam: checkpoint directory creation failed: " ++ error.toString)
    match ← Loam.HouseholdAuthority.installInitial? archiveRoot generation.image with
    | .error message => return .error message
    | .ok installed =>
        if installed.wire != generation.wire then
          return .error "loam: checkpoint differs from observed source generation"
        return .ok (Loam.HouseholdAuthority.path archiveRoot)

/--
Select an internally closed calendar-year excerpt using the *existing* admitted
Actual evidence and NormalizedActual codec. It is only a read-only current
projection. Cross-year corrections/reversals/relations are refused, rather than
dropping references or inventing a carry. Settlement evidence is currently
refused until its complete cross-year closure is supported.
-/
def extractActualEvidence (image : Loam.ActualAuthority.Image) (year : String) :
    Except String Loam.ActualEvidence := do
  let src := image.evidence
  if src.settlements != Loam.Core.SettlementEvidence.empty then
    throw "loam: annual extraction cannot yet preserve settlement dependencies"
  let wantedDate := year ++ "-"
  let included := src.events.events.filter fun event =>
    (Loam.Core.ActualValidityMemory.findByEventId?
      image.currentValidities event.id).any (·.startsWith wantedDate)
  if included.isEmpty then
    throw s!"loam: no admitted Actual events for year {year}"
  let ids := included.map (·.id)
  let has := fun id => ids.any (· == id)
  if src.corrections.corrections.any (fun edge =>
       has edge.target != has edge.replacement) then
    throw "loam: year crosses a correction; archive needs cross-year carry"
  if src.reversals.reversals.any (fun edge =>
       has edge.target != has edge.reversal) then
    throw "loam: year crosses a reversal; archive needs cross-year carry"
  let relations := src.relations.filter fun item => has item.sourceEvent
  let relationIds := relations.map (·.id)
  if src.discharges.any (fun item =>
       has item.event != relationIds.any (· == item.target)) then
    throw "loam: year crosses a relation discharge; archive needs cross-year carry"
  let events ←
    (Loam.Core.EventMemory.ofEvents? included).toExcept
      "loam: annual event subset has invalid identities"
  let facts := src.validity.facts.filter fun item => has item.event
  let refs := facts.map Loam.Core.ActualValidityFact.ref
  let validities := src.validity.corrections.filter fun item =>
    refs.any (· == item.target)
  if validities.any (fun item => !refs.any (· == .revision item.replacement)) then
    throw "loam: year excerpt has dangling date revisions"
  let validity ←
    (Loam.Core.ActualValidityHistory.ofParts? facts validities).toExcept
      "loam: annual validity subset is invalid"
  let descriptions ←
    (Loam.Core.EventDescriptionMemory.ofEntries?
      (src.descriptions.entries.filter fun item => has item.event)).toExcept
        "loam: annual descriptions are invalid"
  let merchants ←
    (Loam.Core.EventMerchantEvidenceMemory.ofEntries?
      (src.merchants.entries.filter fun item => has item.event)).toExcept
        "loam: annual merchant evidence is invalid"
  let exchanges ←
    (Loam.Core.ExchangeEvidenceMemory.ofEntries?
      (src.exchanges.entries.filter fun item => has item.event)).toExcept
        "loam: annual exchange evidence is invalid"
  let originalAmounts ←
    (Loam.Core.OriginalAmountEvidenceMemory.ofEntries?
      (src.originalAmounts.entries.filter fun item => has item.event)).toExcept
        "loam: annual original amounts are invalid"
  let movementOperations ←
    (Loam.Core.MovementOperationEvidenceMemory.ofEntries?
      (src.movementOperations.entries.filter fun item => has item.event)).toExcept
        "loam: annual operation identities are invalid"
  let corrections ←
    (Loam.Core.EventCorrectionMemory.ofCorrections?
      (src.corrections.corrections.filter fun item => has item.target)).toExcept
        "loam: annual correction identities are invalid"
  let reversals ←
    (Loam.Core.ActualReversalMemory.ofReversals?
      (src.reversals.reversals.filter fun item => has item.target)).toExcept
        "loam: annual reversal identities are invalid"
  let excerpt : Loam.ActualEvidence := {
    events, validity, descriptions, merchants, exchanges, originalAmounts,
    movementOperations, corrections, reversals, relations,
    discharges := src.discharges.filter fun item => has item.event,
    settlements := Loam.Core.SettlementEvidence.empty
  }
  let some admitted := Loam.Persistence.admitActualImage? excerpt
    | throw "loam: year excerpt failed standard Actual semantic admission"
  let original ← Loam.ActualJournalProjection.fromImage? image
  let extracted ← Loam.ActualJournalProjection.fromImage? admitted
  let selected := original.filter (·.validOn.startsWith wantedDate)
  if extracted.map (fun e => (e.event, e.validOn, e.description)) !=
      selected.map (fun e => (e.event, e.validOn, e.description)) then
    throw "loam: year excerpt disagrees with current Actual projection"
  return excerpt

/-- Write a bounded, read-only year Actual file without modifying or replacing
the installed HouseholdImage. No year directory, checkpoint or existing excerpt
is overwritten, even when only a partial directory exists. -/
def extractYear (root : System.FilePath) (year : String) :
    IO (Except String System.FilePath) := do
  if !validYear year then
    return .error "loam: extraction year must be four digits (YYYY)"
  let now? ← Loam.ActualDate.todayIso?
  let some now := now? | return .error "loam: current calendar date is unavailable"
  if year >= (now.splitOn "-").head! then
    return .error "loam: extraction requires an already-ended calendar year"
  let archiveRoot := Loam.HouseholdPaths.yearRoot root year
  let target := extractedActualPath root year
  Loam.HouseholdAuthority.withOwnership root do
    if ← archiveRoot.pathExists then
      return .error s!"loam: year {year} destination already exists; no overwrite"
    let image ←
      match ← Loam.ActualAuthority.loadHouseholdImage? root with
      | .ok image => pure image
      | .error message => return .error message
    let excerpt ←
      match extractActualEvidence image year with
      | .ok excerpt => pure excerpt
      | .error message => return .error message
    try
      IO.FS.createDirAll archiveRoot
      Loam.WriterOwnership.withOwnership target do
        if ← target.pathExists then
          return .error "loam: year excerpt already exists"
        match ← Loam.ActualAuthority.publishActualFile? target excerpt with
        | .error message => return .error message
        | .ok () =>
            -- Verify the actual file through the existing production reader.
            match ← Loam.ActualAuthority.loadImageFile? target with
            | .error message => return .error message
            | .ok qualified =>
                let selected ←
                  match Loam.ActualJournalProjection.fromImage? qualified with
                  | .ok rows => pure rows
                  | .error message => return .error message
                if selected.isEmpty || selected.any
                    (fun row => !row.validOn.startsWith (year ++ "-")) then
                  return .error "loam: saved year file has invalid Actual dates"
                return .ok target
    catch error =>
      return .error ("loam: annual extraction failed: " ++ error.toString)

private def effectLine (effect : Effect) : String :=
  "  " ++ effect.coordinate.locus.token ++
  "\t" ++ toString effect.quantity.quanta ++
  "\t" ++ effect.coordinate.measure.token

private def entryLines (entry : Loam.ActualJournalProjection.Entry) : List String :=
  let heading := entry.validOn ++ "\t" ++ entry.event.id.token ++
    match entry.description with
    | some description => "\t" ++ Loam.Persistence.escapeText description
    | none => ""
  heading :: entry.event.effects.map effectLine

def render (year : String) (report : Report) : String :=
  String.intercalate "\n" <|
    [ "LOAM / " ++ year ++ " Actual (read-only)"
    , "Source: " ++ report.sourceFile.toString
    , "Current-effective dated records in selected source: " ++
        toString report.entries.length
    , "Older saved sources may not contain corrections admitted later."
    , ""
    ] ++ report.entries.flatMap entryLines

private def resolveRoot (path? : Option String) :
    IO (Except String System.FilePath) := do
  match path? with
  | some path =>
      if path.isEmpty then return .error "loam: household root must not be empty"
      return .ok (System.FilePath.mk path)
  | none =>
      match ← IO.getEnv "LOAM_DATA_DIR" with
      | some path =>
          if path.isEmpty then return .error "loam: LOAM_DATA_DIR must not be empty"
          return .ok (System.FilePath.mk path)
      | none => return .ok (System.FilePath.mk "../loam-data")

def run (args : List String) : IO UInt32 := do
  let (mode, year, root?) ←
    match args with
    | ["extract", year] => pure (2, year, none)
    | ["extract", year, root] => pure (2, year, some root)
    | ["checkpoint", year] => pure (1, year, none)
    | ["checkpoint", year, root] => pure (1, year, some root)
    | [year] => pure (0, year, none)
    | [year, root] => pure (0, year, some root)
    | _ =>
        IO.eprintln "Usage: loam year YYYY [LOAM_DATA_DIR]"
        IO.eprintln "       loam year extract YYYY [LOAM_DATA_DIR]"
        IO.eprintln "       loam year checkpoint YYYY [LOAM_DATA_DIR]"
        return 2
  let root ←
    match ← resolveRoot root? with
    | .ok root => pure root
    | .error message => IO.eprintln message; return 2
  if mode == 2 then
    match ← extractYear root year with
    | .ok path =>
        IO.println ("Read-only year Actual excerpt created at: " ++ path.toString)
        IO.println "Bounded as-of Actual, not canonical household or complete year-close."
        return 0
    | .error message =>
        IO.eprintln message
        return 2
  else if mode == 1 then
    match ← checkpointYear root year with
    | .ok path =>
        IO.println ("Read-only year checkpoint created at: " ++ path.toString)
        IO.println "Full source generation as-of creation; NOT a partition, final close, or current corrected truth."
        return 0
    | .error message =>
        IO.eprintln message
        return 2
  else
    match ← readYear root year with
    | .ok report =>
        IO.println (render year report)
        return 0
    | .error message =>
        IO.eprintln message
        return 2

end Loam.YearCli
