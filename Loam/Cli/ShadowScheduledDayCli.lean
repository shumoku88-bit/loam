import Loam.Core.Event
import Std

namespace Loam.ShadowScheduledDayCli

open Loam.Core

set_option autoImplicit false

private inductive RetirementEvidence where
  | cancellation (day : String)
  | supersession (day : String)
  deriving Repr

private structure PendingPlan where
  eventIndex : Nat
  lineNo : Nat
  day : String
  context : String
  planId : Option String := none
  retirement : Option RetirementEvidence := none
  effects : List Effect := []
  nextEffectIndex : Nat := 0

private structure ScheduledOccurrence where
  planId : String
  day : String
  context : String
  event : Event
  retirement : Option RetirementEvidence

private structure PlanParseState where
  plans : List ScheduledOccurrence := []
  current : Option PendingPlan := none
  nextEventIndex : Nat := 0
  includeDirectives : Nat := 0
  errorLines : List Nat := []

private structure PendingActual where
  lineNo : Nat
  day : String
  planId : Option String := none

private structure CompletionEvidence where
  planId : String
  day : String

private structure ActualParseState where
  completions : List CompletionEvidence := []
  current : Option PendingActual := none
  includeDirectives : Nat := 0
  errorLines : List Nat := []

private def isDayToken (text : String) : Bool :=
  match text.toList with
  | [a, b, c, d, '-', e, f, '-', g, h] =>
      a.isDigit && b.isDigit && c.isDigit && d.isDigit &&
      e.isDigit && f.isDigit && g.isDigit && h.isDigit
  | _ => false

private def onOrBefore (left right : String) : Bool :=
  match compare left right with
  | .lt | .eq => true
  | .gt => false

private def normalizeWhitespace (text : String) : String :=
  text.replace "\t" " "

private def nonemptyTokens (text : String) : List String :=
  (normalizeWhitespace text).splitOn " " |>.filter (fun token => !token.isEmpty)

private def headerParts? (trimmed : String) : Option (String × String) :=
  match nonemptyTokens trimmed with
  | [] => none
  | day :: rest =>
      if isDayToken day then
        some (day, String.intercalate " " rest)
      else
        none

private def metadataValue? (trimmed marker : String) : Option String :=
  if trimmed.startsWith marker then
    let value := (trimmed.drop marker.length).trimAsciiStart.toString
    let value := value.trimAsciiEnd.toString
    if value.isEmpty then none else some value
  else
    none

private def runLocalEventId (eventIndex : Nat) : EventId :=
  ⟨"shadow-scheduled-event-" ++ toString eventIndex⟩

private def runLocalEffectKey (eventIndex effectIndex : Nat) : EffectKey :=
  ⟨"shadow-scheduled-effect-" ++ toString eventIndex ++ "-" ++ toString effectIndex⟩

private def parsePosting
    (eventIndex effectIndex : Nat) (trimmed : String) : Option Effect :=
  match (nonemptyTokens trimmed).reverse with
  | measure :: quantaText :: reversedLocus =>
      let locus := String.intercalate " " reversedLocus.reverse
      if locus.isEmpty then
        none
      else
        match quantaText.toInt? with
        | none => none
        | some quanta =>
            some <|
              Effect.ofQuantity
                (runLocalEffectKey eventIndex effectIndex)
                ⟨locus⟩ ⟨measure⟩ (Quantity.ofQuanta quanta)
  | _ => none

private def finalizePlan (state : PlanParseState) : PlanParseState :=
  match state.current with
  | none => state
  | some pending =>
      match pending.planId, Event.ofEffects? (runLocalEventId pending.eventIndex) pending.effects with
      | some planId, some event =>
          if state.plans.any (fun plan => decide (plan.planId = planId)) then
            { state with current := none, errorLines := pending.lineNo :: state.errorLines }
          else
            { state with
              plans := state.plans ++
                [{ planId := planId
                   day := pending.day
                   context := pending.context
                   event := event
                   retirement := pending.retirement }]
              current := none }
      | _, _ =>
          { state with current := none, errorLines := pending.lineNo :: state.errorLines }

private def scanPlanLines
    (lines : List String) (lineNo : Nat := 1) (state : PlanParseState := {}) : PlanParseState :=
  match lines with
  | [] => finalizePlan state
  | line :: rest =>
      let leftTrimmed := line.trimAsciiStart.toString
      let trimmed := leftTrimmed.trimAsciiEnd.toString
      let indented := leftTrimmed != line
      if trimmed.isEmpty then
        scanPlanLines rest (lineNo + 1) state
      else if !indented && trimmed.startsWith "include " then
        let closed := finalizePlan state
        scanPlanLines rest (lineNo + 1)
          { closed with includeDirectives := closed.includeDirectives + 1 }
      else if !indented && (trimmed.startsWith ";" || trimmed.startsWith "#") then
        scanPlanLines rest (lineNo + 1) state
      else if !indented then
        match headerParts? trimmed with
        | some (day, context) =>
            let closed := finalizePlan state
            let eventIndex := closed.nextEventIndex
            let nextPending : PendingPlan :=
              { eventIndex := eventIndex
                lineNo := lineNo
                day := day
                context := context }
            scanPlanLines rest (lineNo + 1)
              { closed with
                current := some nextPending
                nextEventIndex := eventIndex + 1 }
        | none =>
            scanPlanLines rest (lineNo + 1)
              { state with errorLines := lineNo :: state.errorLines }
      else
        match state.current with
        | none =>
            scanPlanLines rest (lineNo + 1)
              { state with errorLines := lineNo :: state.errorLines }
        | some pending =>
            if trimmed.startsWith ";" then
              match metadataValue? trimmed "; plan-id:" with
              | some value =>
                  if pending.planId.isSome then
                    scanPlanLines rest (lineNo + 1)
                      { state with errorLines := lineNo :: state.errorLines }
                  else
                    let updated := { pending with planId := some value }
                    scanPlanLines rest (lineNo + 1) { state with current := some updated }
              | none =>
                  match metadataValue? trimmed "; cancelled-on:" with
                  | some day =>
                      if !isDayToken day || pending.retirement.isSome then
                        scanPlanLines rest (lineNo + 1)
                          { state with errorLines := lineNo :: state.errorLines }
                      else
                        let updated :=
                          { pending with retirement := some (.cancellation day) }
                        scanPlanLines rest (lineNo + 1) { state with current := some updated }
                  | none =>
                      match metadataValue? trimmed "; superseded-on:" with
                      | some day =>
                          if !isDayToken day || pending.retirement.isSome then
                            scanPlanLines rest (lineNo + 1)
                              { state with errorLines := lineNo :: state.errorLines }
                          else
                            let updated :=
                              { pending with retirement := some (.supersession day) }
                            scanPlanLines rest (lineNo + 1) { state with current := some updated }
                      | none =>
                          scanPlanLines rest (lineNo + 1) state
            else
              match parsePosting pending.eventIndex pending.nextEffectIndex trimmed with
              | none =>
                  scanPlanLines rest (lineNo + 1)
                    { state with errorLines := lineNo :: state.errorLines }
              | some effect =>
                  let updated :=
                    { pending with
                      effects := pending.effects ++ [effect]
                      nextEffectIndex := pending.nextEffectIndex + 1 }
                  scanPlanLines rest (lineNo + 1) { state with current := some updated }

private def finalizeActual (state : ActualParseState) : ActualParseState :=
  match state.current with
  | none => state
  | some pending =>
      match pending.planId with
      | none => { state with current := none }
      | some planId =>
          if state.completions.any (fun completion => decide (completion.planId = planId)) then
            { state with current := none, errorLines := pending.lineNo :: state.errorLines }
          else
            { state with
              completions := state.completions ++ [{ planId := planId, day := pending.day }]
              current := none }

private def scanActualLines
    (lines : List String) (lineNo : Nat := 1) (state : ActualParseState := {}) : ActualParseState :=
  match lines with
  | [] => finalizeActual state
  | line :: rest =>
      let leftTrimmed := line.trimAsciiStart.toString
      let trimmed := leftTrimmed.trimAsciiEnd.toString
      let indented := leftTrimmed != line
      if trimmed.isEmpty then
        scanActualLines rest (lineNo + 1) state
      else if !indented && trimmed.startsWith "include " then
        let closed := finalizeActual state
        scanActualLines rest (lineNo + 1)
          { closed with includeDirectives := closed.includeDirectives + 1 }
      else if !indented && (trimmed.startsWith ";" || trimmed.startsWith "#") then
        scanActualLines rest (lineNo + 1) state
      else if !indented then
        match headerParts? trimmed with
        | some (day, _) =>
            let closed := finalizeActual state
            let nextPending : PendingActual := { lineNo := lineNo, day := day }
            scanActualLines rest (lineNo + 1)
              { closed with current := some nextPending }
        | none =>
            scanActualLines rest (lineNo + 1)
              { state with errorLines := lineNo :: state.errorLines }
      else
        match state.current with
        | none =>
            scanActualLines rest (lineNo + 1)
              { state with errorLines := lineNo :: state.errorLines }
        | some pending =>
            if trimmed.startsWith ";" then
              match metadataValue? trimmed "; plan-id:" with
              | some value =>
                  if pending.planId.isSome then
                    scanActualLines rest (lineNo + 1)
                      { state with errorLines := lineNo :: state.errorLines }
                  else
                    let updated := { pending with planId := some value }
                    scanActualLines rest (lineNo + 1) { state with current := some updated }
              | none => scanActualLines rest (lineNo + 1) state
            else
              -- Actual bodies are deliberately outside this query. Only explicit
              -- completion coordinates are retained from the already-canonical source.
              scanActualLines rest (lineNo + 1) state

private def retirementVisible (knownThrough : String) : Option RetirementEvidence → Bool
  | none => false
  | some (.cancellation day) => onOrBefore day knownThrough
  | some (.supersession day) => onOrBefore day knownThrough

private def completionVisible
    (knownThrough planId : String) (completions : List CompletionEvidence) : Bool :=
  completions.any fun completion =>
    decide (completion.planId = planId) && onOrBefore completion.day knownThrough

private def planExists (plans : List ScheduledOccurrence) (planId : String) : Bool :=
  plans.any fun plan => decide (plan.planId = planId)

private def planHasRetirement (plans : List ScheduledOccurrence) (planId : String) : Bool :=
  plans.any fun plan => decide (plan.planId = planId) && plan.retirement.isSome

private def printScheduled (plan : ScheduledOccurrence) : IO Unit := do
  if plan.context.isEmpty then
    IO.println "- (scheduled occurrence)"
  else
    IO.println ("- " ++ plan.context)
  for effect in plan.event.effects do
    IO.println
      ("    " ++ effect.locus.token ++ ": " ++
        toString effect.quantity.quanta ++ " " ++ effect.measure.token)

/--
Read the scheduled occurrences for one selected day using only evidence visible
through one known-through horizon.

This adapter intentionally keeps source planning vocabulary outside LOAM Core:
- Plan identity is retained only to resolve explicit Actual completion evidence;
- recurrence, Series, AccountType, cashflow, and source Account declarations are
  not imported;
- completion is never inferred from date, amount, context, or Effect shape;
- cancellation / supersession dates are adapter-local terminal evidence;
- generated Event / Effect identities are run-local and discarded;
- neither source file is modified and no LOAM persistence is written.
-/
def shadowScheduledDay
    (knownThrough selectedDay planPath actualPath : String) : IO UInt32 := do
  if !isDayToken knownThrough || !isDayToken selectedDay then
    IO.eprintln "loam: scheduled day coordinates must be YYYY-MM-DD"
    return 2

  let planSource := System.FilePath.mk planPath
  let actualSource := System.FilePath.mk actualPath
  if !(← planSource.pathExists) || !(← actualSource.pathExists) then
    IO.eprintln "loam: scheduled day source file not found"
    return 2

  let planText ← IO.FS.readFile planSource
  let actualText ← IO.FS.readFile actualSource
  let planParsed := scanPlanLines (planText.splitOn "\n")
  let actualParsed := scanActualLines (actualText.splitOn "\n")

  if !planParsed.errorLines.isEmpty || !actualParsed.errorLines.isEmpty then
    IO.eprintln "loam: scheduled day refused malformed or unsupported source evidence"
    IO.eprintln "loam: no LOAM persistence was written"
    return 2

  for completion in actualParsed.completions do
    if !planExists planParsed.plans completion.planId then
      IO.eprintln "loam: scheduled day found completion for unknown scheduled identity"
      IO.eprintln "loam: no LOAM persistence was written"
      return 2
    if planHasRetirement planParsed.plans completion.planId then
      IO.eprintln "loam: scheduled day found both completion and retirement evidence"
      IO.eprintln "loam: no LOAM persistence was written"
      return 2

  let selected :=
    planParsed.plans.filter fun plan =>
      decide (plan.day = selectedDay) &&
      !retirementVisible knownThrough plan.retirement &&
      !completionVisible knownThrough plan.planId actualParsed.completions

  IO.println ("LOAM scheduled day " ++ selectedDay)
  IO.println ("known through: " ++ knownThrough)
  IO.println "source: read-only; persistence: none; imported source ontology: none"
  if planParsed.includeDirectives != 0 || actualParsed.includeDirectives != 0 then
    IO.println
      ("note: " ++ toString (planParsed.includeDirectives + actualParsed.includeDirectives) ++
        " include directive(s) were not followed by this file-local reader")

  if selected.isEmpty then
    IO.println "  (none scheduled)"
  else
    for plan in selected do
      printScheduled plan

  return 0

end Loam.ShadowScheduledDayCli

def main (args : List String) : IO UInt32 :=
  match args with
  | [knownThrough, selectedDay, planPath, actualPath] =>
      Loam.ShadowScheduledDayCli.shadowScheduledDay
        knownThrough selectedDay planPath actualPath
  | _ => do
      IO.eprintln
        "usage: loamShadowScheduledDay <known-through> <selected-day> <plan-journal> <actual-journal>"
      return 2
