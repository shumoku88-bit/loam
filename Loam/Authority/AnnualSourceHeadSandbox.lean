import Loam.Authority.AnnualSourcePublication
import Loam.Persistence.WriterOwnership

namespace Loam.AnnualSourceHeadSandbox

set_option autoImplicit false

/-!
# One selected native annual HEAD, disposable fixtures only

This does not replace production household.loam. There is NO cryptographic
object identity, trusted publication clock, fsync/parent-directory durability,
valid-old-HEAD rollback detection, migration, or production writer integration.
In particular a complete valid old HEAD rollback is UNDETECTABLE here.
-/

def headHeader : String := "LOAM-ANNUAL-NATIVE-HEAD\t1"
def headPath (root : System.FilePath) : System.FilePath := root / "HEAD"
private def headStage (root : System.FilePath) : System.FilePath := root / "HEAD.loam-stage"
private def baselinePath (root : System.FilePath) (year : String) : System.FilePath :=
  root / "journal" / year / "000000.household.loam"
private def sourcePath (root : System.FilePath) (year : String) (ordinal : Nat) :
    System.FilePath := root / "journal" / year / (toString ordinal ++ ".full.loam")

private def validYear (year : String) : Bool :=
  year.length == 4 && year.toNat?.isSome && year != "0000"

structure Head where
  baselineYear : String
  years : List String := []
  deriving Repr, BEq

structure Selected where
  head : Head
  headWire : String
  generation : Loam.HouseholdAuthority.Generation
  operations : List String
  lastDay : String

def Head.encode (head : Head) : String :=
  headHeader ++ "\nBASE\t" ++ head.baselineYear ++ "\n" ++
    String.join (head.years.zipIdx.map fun (year, index) =>
      "PUB\t" ++ year ++ "\t" ++ toString (index + 1) ++ "\n")

def Head.decode? (wire : String) : Except String Head := do
  let rows := wire.splitOn "\n"
  let [first, baseRow] := rows.take 2
    | throw "loam: annual HEAD missing header or baseline"
  if first != headHeader then
    throw "loam: unsupported annual HEAD version"
  let baselineYear ←
    match baseRow.splitOn "\t" with
    | ["BASE", year] => pure year
    | _ => throw "loam: invalid annual HEAD baseline"
  if !validYear baselineYear then
    throw "loam: annual HEAD baseline year invalid"
  let mut years : List String := []
  for row in (rows.drop 2).filter (· != "") do
    let [marker, year, ordinalText] := row.splitOn "\t"
      | throw "loam: invalid annual HEAD source row"
    if marker != "PUB" || !validYear year then
      throw "loam: invalid annual HEAD source year"
    let some ordinal := ordinalText.toNat?
      | throw "loam: invalid annual HEAD ordinal"
    if ordinal != years.length + 1 then
      throw "loam: noncontiguous annual HEAD ordinal"
    let priorYear := years.getLast?.getD baselineYear
    if year < priorYear then
      throw "loam: annual HEAD publication year regressed"
    years := years ++ [year]
  let head : Head := { baselineYear, years }
  if head.encode != wire then
    throw "loam: noncanonical annual HEAD representation"
  return head

private def read? (path : System.FilePath) : IO (Except String String) := do
  try
    if !(← path.pathExists) then
      return .error s!"loam: annual source missing: {path}"
    return .ok (← IO.FS.readFile path)
  catch error =>
    return .error s!"loam: annual source unreadable: {path}: {error}"

/-- Read exactly the ordered source closure named by ONE pinned HEAD.
Never select by a directory listing, previous file or derived materialization. -/
def selectedFromWire?
    (root : System.FilePath) (headWire : String) :
    IO (Except String Selected) := do
  let .ok head := Head.decode? headWire
    | return .error "loam: invalid annual HEAD"
  let .ok baselineWire ← read? (baselinePath root head.baselineYear)
    | return .error "loam: annual baseline missing or unreadable"
  let .ok baseline := Loam.AnnualSourceMaterialization.qualifyWire? baselineWire
    | return .error "loam: annual baseline failed native qualification"
  let mut current := baseline
  let mut operations : List String := []
  let mut priorDay := head.baselineYear ++ "-01-01"
  for (year, index) in head.years.zipIdx do
    let ordinal := index + 1
    let .ok sourceWire ← read? (sourcePath root year ordinal)
      | return .error s!"loam: annual HEAD referenced missing source {ordinal}"
    let .ok pub := Loam.AnnualSourcePublication.decodeAgainst? current sourceWire
      | return .error s!"loam: annual HEAD source {ordinal} failed replay"
    if pub.ordinal != ordinal || pub.year != year ||
        pub.predecessor != ("ordinal-" ++ toString index) ||
        pub.admittedDay < priorDay || operations.contains pub.operation then
      return .error s!"loam: annual HEAD source {ordinal} violates chain chronology or identity"
    current := pub.generation
    operations := operations ++ [pub.operation]
    priorDay := pub.admittedDay
  return .ok { head, headWire, generation := current, operations, lastDay := priorDay }

def readSelected? (root : System.FilePath) : IO (Except String Selected) := do
  let .ok headWire ← read? (headPath root)
    | return .error "loam: selected annual HEAD missing or unreadable"
  selectedFromWire? root headWire

private def stageAndCheck? (stage : System.FilePath) (wire : String) :
    IO (Except String Unit) := do
  IO.FS.writeFile stage wire
  if (← IO.FS.readFile stage) != wire then
    return .error "loam: staged annual source bytes differ"
  return .ok ()

/-- Explicit bootstrap on an isolated synthetic root ONLY.
A crash before HEAD can leave an orphan and retry must refuse. -/
def bootstrap? (root : System.FilePath) (baselineYear wire : String) :
    IO (Except String Selected) := do
  if !validYear baselineYear then
    return .error "loam: annual bootstrap year invalid"
  let .ok generation := Loam.AnnualSourceMaterialization.qualifyWire? wire
    | return .error "loam: annual bootstrap source invalid"
  IO.FS.createDirAll root
  Loam.WriterOwnership.withOwnership (headPath root) do
    let base := baselinePath root baselineYear
    if (← (headPath root).pathExists) || (← base.pathExists) then
      return .error "loam: annual bootstrap existing HEAD or baseline"
    IO.FS.createDirAll (root / "journal" / baselineYear)
    let stage := root / "journal" / baselineYear / "baseline.loam-stage"
    let .ok () ← stageAndCheck? stage wire
      | return .error "loam: baseline stage failed"
    IO.FS.rename stage base
    let .ok reopened ← read? base
      | return .error "loam: baseline readback failed"
    if reopened != generation.wire then
      return .error "loam: installed baseline mismatch"
    let head : Head := { baselineYear }
    let headWire := head.encode
    let .ok () ← stageAndCheck? (headStage root) headWire
      | return .error "loam: HEAD stage failed"
    IO.FS.rename (headStage root) (headPath root)
    selectedFromWire? root headWire

/-- Prototype hook for **disposable failure injection** immediately after an
immutable source object is installed and rechecked, before HEAD staging. This
is NOT a production writer entrypoint. The caller must not point it at a real
household or treat injection as a power-loss guarantee. -/
def appendWithInstalledTestHook?
    (root : System.FilePath)
    (observedHeadWire admittedDay operation : String)
    (changedNames : List String)
    (candidate : Loam.Persistence.HouseholdImage.Image)
    (afterInstalled : IO Unit) :
    IO (Except String Selected) := do
  Loam.WriterOwnership.withOwnership (headPath root) do
    let .ok headWire ← read? (headPath root)
      | return .error "loam: annual append missing selected HEAD"
    if headWire != observedHeadWire then
      return .error "loam: stale observed annual HEAD"
    let .ok selected ← selectedFromWire? root headWire
      | return .error "loam: selected annual history is not replayable"
    if admittedDay < selected.lastDay || selected.operations.contains operation then
      return .error "loam: annual admission regression or duplicate operation"
    let ordinal := selected.head.years.length + 1
    let .ok pub := Loam.AnnualSourcePublication.prepare?
        selected.generation ordinal admittedDay operation
        ("ordinal-" ++ toString (ordinal - 1))
        changedNames candidate
      | return .error "loam: native annual transition rejected"
    let path := sourcePath root pub.year ordinal
    let sourceWire := Loam.AnnualSourcePublication.encodePublication pub
    if ← path.pathExists then
      -- A process can die AFTER this exact immutable object was installed
      -- and BEFORE HEAD changed. Adopt only a byte-identical, fully requalified
      -- object for the SAME ordinal, predecessor, day, operation, families and
      -- resulting entire native image. Never truncate or delete a different
      -- orphan, even if its internal structure is otherwise well formed.
      let .ok existing ← read? path
        | return .error "loam: existing annual orphan is unreadable"
      if existing != sourceWire then
        return .error "loam: occupied annual source differs from exact retry; recovery required"
      let .ok existingPublication :=
          Loam.AnnualSourcePublication.decodeAgainst? selected.generation existing
        | return .error "loam: existing annual orphan is not a qualified source operation"
      if existingPublication.ordinal != pub.ordinal ||
          existingPublication.admittedDay != pub.admittedDay ||
          existingPublication.operation != pub.operation ||
          existingPublication.predecessor != pub.predecessor ||
          existingPublication.changedNames != pub.changedNames ||
          existingPublication.generation.wire != pub.generation.wire then
        return .error "loam: annual orphan identity mismatch; recovery required"
    else
      IO.FS.createDirAll (root / "journal" / pub.year)
      let stage := System.FilePath.mk (path.toString ++ ".loam-stage")
      let .ok () ← stageAndCheck? stage sourceWire
        | return .error "loam: source object stage failed"
      let .ok checked := Loam.AnnualSourcePublication.decodeAgainst?
          selected.generation (← IO.FS.readFile stage)
        | return .error "loam: staged source object failed native replay"
      if checked.generation.wire != pub.generation.wire then
        return .error "loam: staged source object mismatched candidate"
      IO.FS.rename stage path
    let .ok installed ← read? path
      | return .error "loam: source object missing before HEAD"
    if installed != sourceWire then
      return .error "loam: installed source object changed"
    let .ok checkedInstalled :=
        Loam.AnnualSourcePublication.decodeAgainst? selected.generation installed
      | return .error "loam: installed annual source failed native qualification"
    if checkedInstalled.generation.wire != pub.generation.wire then
      return .error "loam: installed annual source does not match requested generation"
    afterInstalled
    let newHead : Head := { selected.head with years := selected.head.years ++ [pub.year] }
    let newWire := newHead.encode
    let .ok () ← stageAndCheck? (headStage root) newWire
      | return .error "loam: new HEAD stage failed"
    let .ok tested ← selectedFromWire? root newWire
      | return .error "loam: candidate HEAD failed complete replay"
    if tested.generation.wire != pub.generation.wire then
      return .error "loam: candidate HEAD materialization mismatch"
    IO.FS.rename (headStage root) (headPath root)
    return .ok tested

/-- One process-visible HEAD switch after a fully requalified native source.
A byte-exact orphan for the same still-uncommitted operation may be safely
reused. Already committed operations and different orphans are refused.
Neither rename nor equality establishes fsync durability or freshness. -/
def append?
    (root : System.FilePath)
    (observedHeadWire admittedDay operation : String)
    (changedNames : List String)
    (candidate : Loam.Persistence.HouseholdImage.Image) :
    IO (Except String Selected) :=
  appendWithInstalledTestHook? root observedHeadWire admittedDay operation
    changedNames candidate (pure ())

end Loam.AnnualSourceHeadSandbox
