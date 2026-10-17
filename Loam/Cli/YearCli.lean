import Loam.HouseholdPaths
import Loam.ActualDate
import Loam.Cli.NewHouseholdCli
import Loam.Authority.HouseholdAuthority
import Loam.Persistence.WriterOwnership
import Loam.Authority.ActualAuthority
import Loam.Review.ActualJournalProjection
import Loam.Review.CurrentBalanceReview
import Loam.Review.HistoricalBalanceReview
import Loam.Review.ScheduledReview
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
  notice : Option String := none

/-- Existing NormalizedActual codec, not a new annual wire format. -/
def extractedActualPath (root : System.FilePath) (year : String) : System.FilePath :=
  Loam.HouseholdPaths.yearRoot root year / "actual-year.loam"

/-- The displayed effective journal content, with exact Effect identity
and quantities. No proof fields or rendering-dependent whitespace. -/
private def journalIdentity
    (entries : List Loam.ActualJournalProjection.Entry) :
    List (String × String × Option String ×
      List (Option String × String × String × Int)) :=
  entries.map fun entry =>
    (entry.event.id.token, entry.validOn, entry.description,
      entry.event.effects.map fun effect =>
        (effect.key.map (·.token), effect.locus.token,
          effect.measure.token, effect.quantity.quanta))

/-- A saved year is an as-of archive. When the installed HouseholdImage still
retains its events, a later cross-year correction must be visible without
rewriting the immutable archive. -/
private def reconcileSavedYear (root : System.FilePath) (year : String)
    (archived : Report) : IO Report := do
  let current := Loam.HouseholdAuthority.path root
  if !(← current.pathExists) then
    return { archived with
      notice := some "Installed current household is missing; saved-year freshness cannot be checked." }
  let image ←
    match ← Loam.ActualAuthority.loadHouseholdImage? root with
    | .ok image => pure image
    | .error message =>
        return { archived with
          notice := some ("Installed current household unavailable; archive is as-of only: " ++ message) }
  let latest ←
    match Loam.ActualJournalProjection.fromImage? image with
    | .ok entries => pure entries
    | .error message =>
        return { archived with
          notice := some ("Installed current journal unavailable; archive is as-of only: " ++ message) }
  let currentYear := latest.filter fun entry => entry.validOn.startsWith (year ++ "-")
  -- In a future bounded-current-root layout, the active source may have no
  -- old identities at all. That is not evidence of zero historical records.
  let archivedIdsRetained := archived.entries.all fun entry =>
    (image.evidence.events.findById? entry.event.id).isSome
  if !archivedIdsRetained then
    return { archived with
      notice := some "Saved-year as-of view; installed current book does not retain all old identities needed to verify freshness." }
  if journalIdentity currentYear == journalIdentity archived.entries then
    return archived
  -- The installed source still carries this old-year history; it owns
  -- today's correction frontier, not the immutable archive.
  return {
    sourceRoot := root
    sourceFile := current
    entries := currentYear
    notice := some ("Saved year " ++ year ++
      " differs from current admitted corrections; showing current HouseholdImage instead.")
  }

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
  let report : Report := {
    sourceRoot := sourceRoot
    sourceFile := sourceFile
    entries := dated
  }
  if archivePresent then
    return .ok (← reconcileSavedYear root year report)
  return .ok report

/--
A carry candidate from one admitted household generation. The coordinate
classification is deliberately unchanged: exact rows, known-present/unknown
amount, and unsupported are three distinct states. The Scheduled entries are
the real admitted current-open obligations, never merely due-date estimates.

This value is not a Jan-1 opening balance: the source generation has no
publication timestamp. A future rollover publisher must separately justify
its year boundary before installing a compact generation.
-/
structure CarryState where
  balances : Loam.CurrentBalanceReview.Snapshot
  openScheduled : List (String × String)
  scheduledBody : Option String
deriving Repr

/-- Qualify a possible carry from one exact observed generation. No IO, no new
support authority, and no fabricated starting balances or Scheduled items. -/
def carryState? (generation : Loam.HouseholdAuthority.Generation)
    (actual : Loam.ActualAuthority.Image) : Except String CarryState := do
  let balances ← Loam.CurrentBalanceReview.projectFromGeneration generation actual
  let scheduled ← Loam.ScheduledReview.fromGenerationForEvents
    generation actual.evidence.events
  let openScheduled ← Loam.ScheduledReview.orderedCurrentOpenRecords scheduled
  return {
    balances := balances,
    openScheduled := openScheduled.map fun item => (item.id.token, item.scheduledOn),
    scheduledBody := Loam.Persistence.HouseholdImage.body? generation.image "Scheduled"
  }

/-- Exact support-state agreement, not a claim of calendar-boundary readiness.
Scheduled source bytes are compared as well as open identities and dates so
amounts and terminal provenance cannot disappear behind a matching list. -/
def carryAgrees (source candidate : CarryState) : Bool :=
  decide (source.balances = candidate.balances) &&
  source.openScheduled == candidate.openScheduled &&
  source.scheduledBody == candidate.scheduledBody

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
    let carried ←
      match carryState? generation actual with
      | .ok state => pure state
      | .error message => return .error ("loam: checkpoint carry unavailable: " ++ message)
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
        let copiedActual ←
          match ← Loam.ActualAuthority.loadHouseholdImage? archiveRoot with
          | .ok image => pure image
          | .error message => return .error message
        let copiedState ←
          match carryState? installed copiedActual with
          | .ok state => pure state
          | .error message =>
              return .error ("loam: copied checkpoint carry unavailable: " ++ message)
        if !carryAgrees carried copiedState then
          return .error "loam: checkpoint does not preserve exact/unknown balances and open Scheduled"
        return .ok (Loam.HouseholdAuthority.path archiveRoot)

private def required {α : Type} (value : Option α) (message : String) :
    Except String α :=
  match value with
  | some found => .ok found
  | none => .error message

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
  if decide (src.settlements ≠ Loam.Core.SettlementEvidence.empty) then
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
    required (Loam.Core.EventMemory.ofEvents? included)
      "loam: annual event subset has invalid identities"
  let facts := src.validity.facts.filter fun item => has item.event
  let refs := facts.map Loam.Core.ActualValidityFact.ref
  let validities := src.validity.corrections.filter fun item =>
    refs.any (· == item.target)
  if validities.any (fun item =>
      !refs.any (fun ref => ref == Loam.Core.ActualValidityRef.revision item.replacement)) then
    throw "loam: year excerpt has dangling date revisions"
  let validity ←
    required (Loam.Core.ActualValidityHistory.ofParts? facts validities)
      "loam: annual validity subset is invalid"
  let descriptions ←
    required (Loam.Core.EventDescriptionMemory.ofEntries?
      (src.descriptions.entries.filter fun item => has item.event))
      "loam: annual descriptions are invalid"
  let merchants ←
    required (Loam.Core.EventMerchantEvidenceMemory.ofEntries?
      (src.merchants.entries.filter fun item => has item.event))
      "loam: annual merchant evidence are invalid"
  let exchanges ←
    required (Loam.Core.ExchangeEvidenceMemory.ofEntries?
      (src.exchanges.entries.filter fun item => has item.event))
      "loam: annual exchange evidence are invalid"
  let originalAmounts ←
    required (Loam.Core.OriginalAmountEvidenceMemory.ofEntries?
      (src.originalAmounts.entries.filter fun item => has item.event))
      "loam: annual original amounts are invalid"
  let movementOperations ←
    required (Loam.Core.MovementOperationEvidenceMemory.ofEntries?
      (src.movementOperations.entries.filter fun item => has item.event))
      "loam: annual operation identities are invalid"
  let corrections ←
    required (Loam.Core.EventCorrectionMemory.ofCorrections?
      (src.corrections.corrections.filter fun item => has item.target))
      "loam: annual correction identities are invalid"
  let reversals ←
    required (Loam.Core.ActualReversalMemory.ofReversals?
      (src.reversals.reversals.filter fun item => has item.target))
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
  if extracted.map (fun e => (e.event.id, e.validOn, e.description)) !=
      selected.map (fun e => (e.event.id, e.validOn, e.description)) then
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

/--
Read an exact Jan-1 opening boundary using the *existing* historical balance
reconstructor. A current quantity, even when exact, is not enough to claim an
exact quantity at an earlier calendar boundary.

Unproven coordinates remain explicitly unavailable with the existing
historical-support refusal reason. Scheduled evidence is inspected through its
normal current-open reader but is deliberately NOT called Jan-1 Scheduled: its
lifecycle terminal evidence has no independently admitted publication time.
-/
structure OpeningReview where
  startOfDay : String
  exact : List Loam.HistoricalBalanceReview.Row
  unavailable : List (EffectCoordinate × String)
  currentOpenScheduled : List (String × String)
deriving Repr

private def isUnavailableHistoricalSupport (message : String) : Bool :=
  message.startsWith "loam: historical balance unavailable: historical support missing" ||
  message.startsWith "loam: historical balance unavailable: opening support does not justify" ||
  message.startsWith "loam: historical balance unavailable: bounded history support missing" ||
  message.startsWith "loam: historical balance unavailable: requested boundary precedes bounded history start"

def openingReview?
    (generation : Loam.HouseholdAuthority.Generation)
    (actual : Loam.ActualAuthority.Image)
    (year : String) : Except String OpeningReview := do
  if !validYear year then
    throw "loam: opening review requires a valid four-digit calendar year"
  let startOfDay := year ++ "-01-01"
  let current ← Loam.CurrentBalanceReview.projectFromGeneration generation actual
  let historical ← Loam.HistoricalBalanceReview.evidenceFromGeneration generation
  let scheduled ← Loam.ScheduledReview.fromGenerationForEvents
    generation actual.evidence.events
  let openScheduled ← Loam.ScheduledReview.orderedCurrentOpenRecords scheduled
  let coordinates := (current.rows.map (·.coordinate) ++
    current.knownPresent ++ current.unsupported).eraseDups
  let mut exact : List Loam.HistoricalBalanceReview.Row := []
  let mut unavailable : List (EffectCoordinate × String) := []
  for coordinate in coordinates do
    match Loam.HistoricalBalanceReview.projectStartOfDay
        actual historical startOfDay [coordinate] with
    | .ok snapshot =>
        exact := exact ++ snapshot.rows
    | .error message =>
        if !isUnavailableHistoricalSupport message then
          throw message
        unavailable := unavailable ++ [(coordinate, message)]
  return {
    startOfDay := startOfDay,
    exact := exact,
    unavailable := unavailable,
    currentOpenScheduled := openScheduled.map fun item =>
      (item.id.token, item.scheduledOn)
  }

/-- One qualified current generation with an independently justified boundary
projection. The root is never mutated. -/
def inspectOpening (root : System.FilePath) (year : String) :
    IO (Except String OpeningReview) := do
  if !validYear year then
    return .error "loam: opening review requires a valid four-digit calendar year"
  let some today ← Loam.ActualDate.todayIso?
    | return .error "loam: local calendar day unavailable for opening review"
  if decide (today < year ++ "-01-01") then
    return .error "loam: future Jan-1 opening is not yet historical; no future quantity can be certified"
  let observed ←
    match ← Loam.ActualAuthority.loadHouseholdObserved? root with
    | .ok observed => pure observed
    | .error message => return .error message
  return openingReview? observed.generation observed.image year

/-- Retain the exact Measure with every quantity; unknown is never formatted
as an arithmetic zero. Current Scheduled is informational, not date-qualified. -/
def renderOpening (review : OpeningReview) : String :=
  String.intercalate "\n" <|
    ["LOAM / " ++ review.startOfDay ++ " opening boundary (read-only)",
     "Uses today's corrected Actual truth, not necessarily what was known on Jan 1.",
     "Exact historical quantities: " ++ toString review.exact.length,
     "Unavailable historical quantities: " ++ toString review.unavailable.length] ++
    (review.exact.map fun row =>
      "EXACT\t" ++ row.coordinate.locus.token ++ "\t" ++
      row.coordinate.measure.token ++ "\t" ++ toString row.quantity.quanta) ++
    (review.unavailable.map fun (coordinate, reason) =>
      "UNAVAILABLE\t" ++ coordinate.locus.token ++ "\t" ++
      coordinate.measure.token ++ "\t" ++ reason) ++
    ["Current-open Scheduled: " ++ toString review.currentOpenScheduled.length,
     "Scheduled shown below is current-open NOW, not certified open on Jan 1."] ++
    (review.currentOpenScheduled.map fun (id, date) =>
      "CURRENT-SCHEDULED\t" ++ id ++ "\t" ++ date) ++
    ["This is not a verified year close, writable carry or future forecast."]

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
    ] ++
    (match report.notice with
      | some notice => ["Notice: " ++ notice]
      | none => []) ++
    [ "Older saved sources may not contain corrections admitted later."
    , ""
    ] ++ report.entries.flatMap entryLines

/--
A deliberately independent, empty calendar-year book. This is the existing
`loam init` installer under a convenient year-named path, NOT a rollover or
a partition. We do not copy balances, Scheduled or any journal/config facts.
`books/YYYY` avoids the reserved read-only `journal/YYYY` archive topology.
-/
def independentBookPath (root : System.FilePath) (year : String) : System.FilePath :=
  root / "books" / year

def newIndependentBook (root : System.FilePath) (year : String) :
    IO (Except String System.FilePath) := do
  if !validYear year then
    return .error "loam: independent book year must be four digits (YYYY)"
  -- A misspelled, missing, or malformed source is not a reason to manufacture
  -- a separate book elsewhere. Qualify the explicitly selected parent first.
  match ← Loam.HouseholdAuthority.loadCurrent? root with
  | .error message => return .error message
  | .ok _ => pure ()
  let destination := independentBookPath root year
  if ← destination.pathExists then
    return .error ("loam: independent year book already exists: " ++ destination.toString)
  match ← Loam.NewHouseholdCli.create destination with
  | .error message => return .error message
  | .ok () => return .ok destination

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
    | ["new", year] => pure (4, year, none)
    | ["new", year, root] => pure (4, year, some root)
    | ["opening", year] => pure (3, year, none)
    | ["opening", year, root] => pure (3, year, some root)
    | ["extract", year] => pure (2, year, none)
    | ["extract", year, root] => pure (2, year, some root)
    | ["checkpoint", year] => pure (1, year, none)
    | ["checkpoint", year, root] => pure (1, year, some root)
    | [year] => pure (0, year, none)
    | [year, root] => pure (0, year, some root)
    | _ =>
        IO.eprintln "Usage: loam year YYYY [LOAM_DATA_DIR]"
        IO.eprintln "       loam year new YYYY [LOAM_DATA_DIR]"
        IO.eprintln "       loam year opening YYYY [LOAM_DATA_DIR]"
        IO.eprintln "       loam year extract YYYY [LOAM_DATA_DIR]"
        IO.eprintln "       loam year checkpoint YYYY [LOAM_DATA_DIR]"
        return 2
  let root ←
    match ← resolveRoot root? with
    | .ok root => pure root
    | .error message => IO.eprintln message; return 2
  if mode == 4 then
    match ← newIndependentBook root year with
    | .ok destination =>
        IO.println ("Independent " ++ year ++ " book created: " ++ destination.toString)
        IO.println ("Open it with: loam tui " ++ destination.toString)
        IO.println "No balances, Scheduled or history were copied. Set up Loci, roles, known balances and future payments as needed."
        IO.println "The previous household is unchanged; no new default was selected."
        return 0
    | .error message =>
        IO.eprintln message
        return 2
  else if mode == 3 then
    match ← inspectOpening root year with
    | .ok opening =>
        IO.println (renderOpening opening)
        return 0
    | .error message =>
        IO.eprintln message
        return 2
  else if mode == 2 then
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
