from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text()

def write(path, text):
    (ROOT / path).write_text(text)

def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

# 1. Keep ScheduledOccurrenceConstruction as the small shared mechanics owner:
# fresh identity plus a derived positive total. Retire Effect -> movement adapters
# now that publisher drafts carry BalancedMovement directly.
path = "Loam/ScheduledOccurrenceConstruction.lean"
text = read(path)
text = re.sub(
    r"\ndef movementFromEffects\? \(effects : List Effect\) : Option \(BalancedMovement LocusId\) := do\n.*?\nend Loam\.ScheduledOccurrenceConstruction\n",
    "\n/-- Derived positive-side total of one already-balanced Scheduled movement. -/\ndef positiveTotalQuanta (movement : BalancedMovement LocusId) : Int :=\n  movement.changes.foldl\n    (fun total change => total + max 0 change.quantity.quanta) 0\n\nend Loam.ScheduledOccurrenceConstruction\n",
    text,
    flags=re.S,
)
if "movementFromEffects?" in text or "occurrenceFromEffects?" in text:
    raise SystemExit("ScheduledOccurrenceConstruction: retired adapters remained")
write(path, text)

# 2. Creation publisher: draft is now canonical Scheduled content.
path = "Loam/ScheduledCreationPublisher.lean"
text = read(path)
text = replace_once(text,
"""structure Draft where
  scheduledOn : String
  effects : List Effect
  total : Int
""",
"""structure Draft where
  scheduledOn : String
  movement : BalancedMovement LocusId
""", "creation Draft")
start = text.index("/-- Anonymous Effects need no persisted identity token; retained keys still do. -/")
end = text.index("\nprivate def publishUnderOwnership", start)
text = text[:start] + """private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw \"loam: Scheduled creation requires a valid ISO calendar date\"
  if draft.movement.measure != ⟨\"jpy\"⟩ then
    throw \"loam: Scheduled creation requires a JPY movement\"
  if draft.movement.changes.isEmpty then
    throw \"loam: Scheduled creation requires at least one movement change\"
  if !draft.movement.changes.all (fun change =>
      Loam.Persistence.validToken change.coordinate.token &&
      change.quantity.quanta != 0) then
    throw \"loam: Scheduled creation requires valid Locus tokens and nonzero JPY quantities\"
  if Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement <= 0 then
    throw \"loam: Scheduled creation requires a positive balanced total\"
""" + text[end:]
text = replace_once(text,
"""  if !locusAdmission.admitsEffects draft.effects then
    return .error \"loam: Scheduled creation uses a Locus not approved for new publication\"
""",
"""  if !draft.movement.changes.all (fun change =>
      locusAdmission.allows change.coordinate) then
    return .error \"loam: Scheduled creation uses a Locus not approved for new publication\"
""", "creation Locus admission")
text = re.sub(
    r"  let occurrence ←\n    match Loam\.ScheduledOccurrenceConstruction\.occurrenceFromEffects\?\n        scheduledId draft\.scheduledOn draft\.effects with\n    \| some occurrence => pure occurrence\n    \| none => return \.error \"loam: Scheduled movement could not be admitted\"\n",
    """  let occurrence : ScheduledOccurrence String := {
    id := scheduledId
    scheduledOn := draft.scheduledOn
    movement := draft.movement
  }
""", text, count=1)
text = replace_once(text, "    total := draft.total\n", "    total := Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement\n", "creation receipt total")
if "draft.effects" in text or "draft.total" in text or "retainedEffectKeyPersistable" in text:
    raise SystemExit("creation publisher retained old draft surface")
write(path, text)

# 3. Replacement publisher follows the same canonical movement shape.
path = "Loam/ScheduledReplacementPublisher.lean"
text = read(path)
text = replace_once(text,
"""structure Draft where
  source : ScheduledId
  scheduledOn : String
  effects : List Effect
  total : Int
""",
"""structure Draft where
  source : ScheduledId
  scheduledOn : String
  movement : BalancedMovement LocusId
""", "replacement Draft")
start = text.index("/-- Anonymous Effects need no persisted identity token; retained keys still do. -/")
end = text.index("\nprivate def transitionAdmissible?", start)
text = text[:start] + """private def validateDraft (draft : Draft) : Except String Unit := do
  if !Loam.ActualDate.validIsoDate draft.scheduledOn then
    throw \"loam: Scheduled replacement requires a valid ISO calendar date\"
  if draft.movement.measure != ⟨\"jpy\"⟩ then
    throw \"loam: Scheduled replacement requires a JPY movement\"
  if draft.movement.changes.isEmpty then
    throw \"loam: Scheduled replacement requires at least one movement change\"
  if !draft.movement.changes.all (fun change =>
      Loam.Persistence.validToken change.coordinate.token &&
      change.quantity.quanta != 0) then
    throw \"loam: Scheduled replacement requires valid Locus tokens and nonzero JPY quantities\"
  if Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement <= 0 then
    throw \"loam: Scheduled replacement requires a positive balanced total\"
""" + text[end:]
text = replace_once(text,
"""  if !locusAdmission.admitsEffects draft.effects then
    return .error \"loam: Scheduled replacement uses a Locus not approved for new publication\"
""",
"""  if !draft.movement.changes.all (fun change =>
      locusAdmission.allows change.coordinate) then
    return .error \"loam: Scheduled replacement uses a Locus not approved for new publication\"
""", "replacement Locus admission")
text = re.sub(
    r"  let occurrence ←\n    match Loam\.ScheduledOccurrenceConstruction\.occurrenceFromEffects\?\n        replacementId draft\.scheduledOn draft\.effects with\n    \| some occurrence => pure occurrence\n    \| none => return \.error \"loam: replacement Scheduled movement could not be admitted\"\n",
    """  let occurrence : ScheduledOccurrence String := {
    id := replacementId
    scheduledOn := draft.scheduledOn
    movement := draft.movement
  }
""", text, count=1)
text = replace_once(text, "    total := draft.total\n", "    total := Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement\n", "replacement receipt total")
if "draft.effects" in text or "draft.total" in text or "retainedEffectKeyPersistable" in text:
    raise SystemExit("replacement publisher retained old draft surface")
write(path, text)

# 4. TUI creation builds canonical movement changes directly. No synthetic EffectKey.
path = "Loam/Tui/ScheduledCreation.lean"
text = read(path)
old = """  let mut effects : List Effect := []
  let mut positive := 0
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    let some amount := row.amount.toInt?
      | throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if amount = 0 then
      throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if !Loam.Persistence.validToken row.locus then
      throw \"Enter a valid Locus token for every posting.\"
    effects := effects ++ [Effect.ofQuantity
      ⟨\"scheduled-create-effect-\" ++ toString (index + 1)⟩ ⟨row.locus⟩ ⟨\"jpy\"⟩
      (Quantity.ofQuanta amount)]
    if amount > 0 then positive := positive + amount
  let changes : List (MovementChange LocusId) :=
    effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  if (BalancedMovement.ofChanges? ⟨\"jpy\"⟩ changes).isNone then
    throw \"Scheduled posting totals differ.\"
  if positive <= 0 then
    throw \"Scheduled creation requires a positive balanced total.\"
  pure {
    scheduledOn := state.form.date
    effects := effects
    total := positive
  }
"""
new = """  let mut changes : List (MovementChange LocusId) := []
  let mut positive := 0
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    let some amount := row.amount.toInt?
      | throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if amount = 0 then
      throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if !Loam.Persistence.validToken row.locus then
      throw \"Enter a valid Locus token for every posting.\"
    changes := changes ++ [{
      coordinate := ⟨row.locus⟩
      quantity := Quantity.ofQuanta amount
    }]
    if amount > 0 then positive := positive + amount
  let some movement := BalancedMovement.ofChanges? ⟨\"jpy\"⟩ changes
    | throw \"Scheduled posting totals differ.\"
  if positive <= 0 then
    throw \"Scheduled creation requires a positive balanced total.\"
  pure {
    scheduledOn := state.form.date
    movement := movement
  }
"""
text = replace_once(text, old, new, "creation TUI draft")
text = replace_once(text,
"""        (draft.effects.take 12).map (fun effect =>
          line (effect.locus.token ++ \"  \" ++ toString effect.quantity.quanta ++ \" jpy\")) ++
        [ line (\"Balanced total: \" ++ toString draft.total ++ \" jpy\")
""",
"""        (draft.movement.changes.take 12).map (fun change =>
          line (change.coordinate.token ++ \"  \" ++ toString change.quantity.quanta ++ \" jpy\")) ++
        [ line (\"Balanced total: \" ++ toString
            (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++ \" jpy\")
""", "creation TUI preview")
if "scheduled-create-effect-" in text or "draft.effects" in text or "draft.total" in text:
    raise SystemExit("creation TUI retained synthetic draft identity")
write(path, text)

# 5. TUI replacement mirrors creation.
path = "Loam/Tui/ScheduledReplacement.lean"
text = read(path)
old = """  let mut effects : List Effect := []
  let mut positive := 0
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    let some amount := row.amount.toInt?
      | throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if amount = 0 then
      throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if !Loam.Persistence.validToken row.locus then
      throw \"Enter a valid Locus token for every posting.\"
    effects := effects ++ [Effect.ofQuantity
      ⟨\"replacement-effect-\" ++ toString (index + 1)⟩ ⟨row.locus⟩ ⟨\"jpy\"⟩
      (Quantity.ofQuanta amount)]
    if amount > 0 then positive := positive + amount
  let changes : List (MovementChange LocusId) :=
    effects.map fun effect =>
      { coordinate := effect.locus, quantity := effect.quantity }
  if (BalancedMovement.ofChanges? ⟨\"jpy\"⟩ changes).isNone then
    throw \"Scheduled replacement posting totals differ.\"
  if positive <= 0 then
    throw \"Scheduled replacement requires a positive balanced total.\"
  pure {
    source := state.target
    scheduledOn := state.form.date
    effects := effects
    total := positive
  }
"""
new = """  let mut changes : List (MovementChange LocusId) := []
  let mut positive := 0
  for index in List.range state.form.rows.size do
    let row := state.form.rows[index]!
    let some amount := row.amount.toInt?
      | throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if amount = 0 then
      throw \"Enter a nonzero signed integer JPY amount for every posting.\"
    if !Loam.Persistence.validToken row.locus then
      throw \"Enter a valid Locus token for every posting.\"
    changes := changes ++ [{
      coordinate := ⟨row.locus⟩
      quantity := Quantity.ofQuanta amount
    }]
    if amount > 0 then positive := positive + amount
  let some movement := BalancedMovement.ofChanges? ⟨\"jpy\"⟩ changes
    | throw \"Scheduled replacement posting totals differ.\"
  if positive <= 0 then
    throw \"Scheduled replacement requires a positive balanced total.\"
  pure {
    source := state.target
    scheduledOn := state.form.date
    movement := movement
  }
"""
text = replace_once(text, old, new, "replacement TUI draft")
text = replace_once(text,
"""        (draft.effects.take 12).map (fun effect =>
          line (effect.locus.token ++ \"  \" ++ toString effect.quantity.quanta ++ \" jpy\")) ++
        [ line (\"Balanced total: \" ++ toString draft.total ++ \" jpy\")
""",
"""        (draft.movement.changes.take 12).map (fun change =>
          line (change.coordinate.token ++ \"  \" ++ toString change.quantity.quanta ++ \" jpy\")) ++
        [ line (\"Balanced total: \" ++ toString
            (Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement) ++ \" jpy\")
""", "replacement TUI preview")
if "replacement-effect-" in text or "draft.effects" in text or "draft.total" in text:
    raise SystemExit("replacement TUI retained synthetic draft identity")
write(path, text)

# 6. Publisher tests construct canonical movement values directly.
path = "Loam/Tests/ScheduledCreationPublisher.lean"
text = read(path)
start = text.index("private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=")
end = text.index("\nprivate def hasScheduled", start)
replacement = """private def movement
    (fromLocus toLocus : String) (amount : Int) : BalancedMovement LocusId := {
  measure := ⟨\"jpy\"⟩
  changes :=
    [ { coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
    ]
  balanced := by simp [movementTotalQuanta]
}

private def draft
    (day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledCreationPublisher.Draft := {
  scheduledOn := day
  movement := movement fromLocus toLocus amount
}
"""
text = text[:start] + replacement + text[end:]
write(path, text)

path = "Loam/Tests/ScheduledReplacementPublisher.lean"
text = read(path)
start = text.index("private def effects (fromLocus toLocus : String) (amount : Int) : List Effect :=")
end = text.index("\nprivate def hasScheduled", start)
replacement = """private def replacementMovement
    (fromLocus toLocus : String) (amount : Int) : BalancedMovement LocusId := {
  measure := ⟨\"jpy\"⟩
  changes :=
    [ { coordinate := ⟨fromLocus⟩, quantity := Quantity.ofQuanta (-amount) }
    , { coordinate := ⟨toLocus⟩, quantity := Quantity.ofQuanta amount }
    ]
  balanced := by simp [movementTotalQuanta]
}

private def replacementDraft
    (source day fromLocus toLocus : String) (amount : Int) :
    Loam.ScheduledReplacementPublisher.Draft := {
  source := ⟨source⟩
  scheduledOn := day
  movement := replacementMovement fromLocus toLocus amount
}
"""
text = text[:start] + replacement + text[end:]
write(path, text)

# 7. UI tests assert the same derived total rather than a duplicated Draft field.
path = "Loam/Tests/TuiScheduledCreate.lean"
text = read(path)
text = replace_once(text,
"expect (draft.scheduledOn == \"2026-09-12\" && draft.total == 700)",
"expect (draft.scheduledOn == \"2026-09-12\" &&\n    Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta draft.movement == 700)",
"creation UI total assertion")
write(path, text)

path = "Loam/Tests/TuiScheduledTerminal.lean"
text = read(path)
text = replace_once(text,
"""      replacementIntent.scheduledOn == \"2026-09-12\" &&
      replacementIntent.total == 300)
""",
"""      replacementIntent.scheduledOn == \"2026-09-12\" &&
      Loam.ScheduledOccurrenceConstruction.positiveTotalQuanta
        replacementIntent.movement == 300)
""", "replacement UI total assertion")
write(path, text)

# Guard the intended semantic cutover.
for path in [
    "Loam/ScheduledCreationPublisher.lean",
    "Loam/ScheduledReplacementPublisher.lean",
    "Loam/Tui/ScheduledCreation.lean",
    "Loam/Tui/ScheduledReplacement.lean",
]:
    text = read(path)
    if "draft.effects" in text or "draft.total" in text:
        raise SystemExit(f"{path}: old Scheduled draft projection remained")

for path in ROOT.glob("Loam/**/*.lean"):
    text = path.read_text()
    if "movementFromEffects?" in text or "occurrenceFromEffects?" in text:
        raise SystemExit(f"{path.relative_to(ROOT)}: retired Scheduled adapter remained")

print("Scheduled Creation/Replacement drafts now carry canonical BalancedMovement directly")
