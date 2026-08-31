import Std

namespace Loam.ShadowAuditCli

set_option autoImplicit false

/--
One source event observed by the privacy-preserving shadow scanner.

The scanner deliberately retains only structural coverage. It never stores a
source description, locus token, measure token, date, amount, or metadata
value in this audit state.
-/
private structure PendingEvent where
  effectCount : Nat := 0
  identifiedEffects : Nat := 0
  hasEventIdentity : Bool := false
  hasMetadata : Bool := false
  nextEffectHasIdentity : Bool := false

/-- Aggregate structural coverage. No source values are retained. -/
private structure Audit where
  eventCount : Nat := 0
  effectCount : Nat := 0
  multiEffectEvents : Nat := 0
  identifiedEvents : Nat := 0
  identifiedEffects : Nat := 0
  eventsWithMetadata : Nat := 0

private def trimAsciiString (text : String) : String :=
  text.trimAsciiStart.toString.trimAsciiEnd.toString

private def looksLikeDateHeader (text : String) : Bool :=
  match text.toList with
  | a :: b :: c :: d :: '-' :: e :: f :: '-' :: g :: h :: _ =>
      a.isDigit && b.isDigit && c.isDigit && d.isDigit &&
      e.isDigit && f.isDigit && g.isDigit && h.isDigit
  | _ => false

private def finalize (audit : Audit) : Option PendingEvent → Audit
  | none => audit
  | some event =>
      { eventCount := audit.eventCount + 1
        effectCount := audit.effectCount + event.effectCount
        multiEffectEvents :=
          audit.multiEffectEvents + (if event.effectCount > 1 then 1 else 0)
        identifiedEvents :=
          audit.identifiedEvents + (if event.hasEventIdentity then 1 else 0)
        identifiedEffects := audit.identifiedEffects + event.identifiedEffects
        eventsWithMetadata :=
          audit.eventsWithMetadata + (if event.hasMetadata then 1 else 0) }

private def eventIdentityMarker (trimmed : String) : Bool :=
  trimmed.startsWith "; event-id:" || trimmed.startsWith "; txn-id:"

private def effectIdentityMarker (trimmed : String) : Bool :=
  trimmed.startsWith "; effect-key:"

private def scanLines
    (lines : List String) (audit : Audit := {})
    (current : Option PendingEvent := none) : Audit :=
  match lines with
  | [] => finalize audit current
  | line :: rest =>
      let leftTrimmed := line.trimAsciiStart.toString
      let trimmed := leftTrimmed.trimAsciiEnd.toString
      let indented := leftTrimmed != line
      if trimmed.isEmpty || trimmed.startsWith "include " then
        scanLines rest audit current
      else if !indented && looksLikeDateHeader trimmed then
        scanLines rest (finalize audit current) (some {})
      else
        match current with
        | none => scanLines rest audit none
        | some event =>
            if indented && trimmed.startsWith ";" then
              let updated :=
                { event with
                  hasEventIdentity := event.hasEventIdentity || eventIdentityMarker trimmed
                  hasMetadata := true
                  nextEffectHasIdentity :=
                    event.nextEffectHasIdentity || effectIdentityMarker trimmed }
              scanLines rest audit (some updated)
            else if indented then
              let updated :=
                { event with
                  effectCount := event.effectCount + 1
                  identifiedEffects :=
                    event.identifiedEffects +
                      (if event.nextEffectHasIdentity then 1 else 0)
                  nextEffectHasIdentity := false }
              scanLines rest audit (some updated)
            else
              scanLines rest audit current

private def coverageLabel (covered total : Nat) : String :=
  if total = 0 || covered = 0 then
    "absent"
  else if covered = total then
    "complete"
  else
    "partial"

private def fullyIdentified (audit : Audit) : Bool :=
  audit.eventCount != 0 &&
  audit.identifiedEvents == audit.eventCount &&
  audit.identifiedEffects == audit.effectCount

private def printStatus (audit : Audit) : IO Unit := do
  IO.println "LOAM private shadow audit"
  IO.println "privacy: raw source values are not emitted"
  IO.println
    ("stable event identity: " ++
      coverageLabel audit.identifiedEvents audit.eventCount)
  IO.println
    ("stable effect identity: " ++
      coverageLabel audit.identifiedEffects audit.effectCount)
  let ready := if fullyIdentified audit then "yes" else "no"
  IO.println
    ("lossless Practical Core projection without invented identity: " ++ ready)

private def printCounts (audit : Audit) : IO Unit := do
  IO.println ("source events: " ++ toString audit.eventCount)
  IO.println ("candidate effects: " ++ toString audit.effectCount)
  IO.println ("multi-effect events: " ++ toString audit.multiEffectEvents)
  IO.println ("events with explicit event identity: " ++ toString audit.identifiedEvents)
  IO.println ("effects with explicit effect identity: " ++ toString audit.identifiedEffects)
  IO.println ("events with opaque metadata: " ++ toString audit.eventsWithMetadata)

/--
Read one external journal-shaped source and report only structural identity
coverage.

The command is intentionally read-only. It does not create a LOAM Event,
EventMemory, sidecar, cache, converted file, or source modification. It also
never prints raw source lines or tokens. `showCounts` reveals only aggregate
structural counts and is therefore opt-in.
-/
def auditFile (path : String) (showCounts : Bool := false) : IO UInt32 := do
  let source := System.FilePath.mk path
  if !(← source.pathExists) then
    IO.eprintln "loam: shadow source file not found"
    return 2
  else
    let text ← IO.FS.readFile source
    let audit := scanLines (text.splitOn "\n")
    printStatus audit
    if showCounts then
      printCounts audit
    return 0

end Loam.ShadowAuditCli
