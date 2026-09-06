import Std

namespace Loam.Prototype.InteractionShell

set_option autoImplicit false

inductive Candidate where
  | hraFlat
  | hybrid
  deriving Repr, DecidableEq, BEq

inductive Surface where
  | home
  | actualHistory
  | scheduledList
  | palette
  | recordDraft
  | correctDraft
  | realizeDraft
  | replaceDraft
  | help
  | stats
  deriving Repr, DecidableEq, BEq

inductive Focus where
  | none
  | actual
  | scheduled
  deriving Repr, DecidableEq, BEq

structure Metrics where
  commands : Nat
  paletteOpens : Nat
  helpOpens : Nat
  unknownCommands : Nat
  dayMoves : Nat
  surfaceChanges : Nat
  deriving Repr

structure State where
  candidate : Candidate
  surface : Surface
  dayIndex : Nat
  focus : Focus
  hraMetrics : Metrics
  hybridMetrics : Metrics
  notice : String
  deriving Repr

def emptyMetrics : Metrics :=
  {
    commands := 0
    paletteOpens := 0
    helpOpens := 0
    unknownCommands := 0
    dayMoves := 0
    surfaceChanges := 0
  }

def initialState (candidate : Candidate) : State :=
  {
    candidate := candidate
    surface := .home
    dayIndex := 3
    focus := .none
    hraMetrics := emptyMetrics
    hybridMetrics := emptyMetrics
    notice := ""
  }

def candidateName : Candidate → String
  | .hraFlat => "HRA-derived flat"
  | .hybrid => "flat + palette hybrid"

def mapCurrentMetrics (state : State) (f : Metrics → Metrics) : State :=
  match state.candidate with
  | .hraFlat => { state with hraMetrics := f state.hraMetrics }
  | .hybrid => { state with hybridMetrics := f state.hybridMetrics }

def countCommand (state : State) : State :=
  mapCurrentMetrics state (fun m => { m with commands := m.commands + 1 })

def countPaletteOpen (state : State) : State :=
  mapCurrentMetrics state (fun m => { m with paletteOpens := m.paletteOpens + 1 })

def countHelpOpen (state : State) : State :=
  mapCurrentMetrics state (fun m => { m with helpOpens := m.helpOpens + 1 })

def countUnknown (state : State) : State :=
  mapCurrentMetrics state (fun m => { m with unknownCommands := m.unknownCommands + 1 })

def countDayMove (state : State) : State :=
  mapCurrentMetrics state (fun m => { m with dayMoves := m.dayMoves + 1 })

def countSurfaceChange (state : State) : State :=
  mapCurrentMetrics state (fun m => { m with surfaceChanges := m.surfaceChanges + 1 })

def goSurface (state : State) (surface : Surface) (notice : String := "") : State :=
  let changed := if state.surface == surface then state else countSurfaceChange state
  { changed with surface := surface, focus := .none, notice := notice }

def withNotice (state : State) (notice : String) : State :=
  { state with notice := notice }

def previousDay : Nat → Nat
  | 0 => 0
  | 1 => 0
  | 2 => 1
  | 3 => 2
  | 4 => 3
  | _ => 4

def nextDay : Nat → Nat
  | 0 => 1
  | 1 => 2
  | 2 => 3
  | 3 => 4
  | _ => 4

def dayLabel : Nat → String
  | 0 => "Sep 3"
  | 1 => "Sep 4"
  | 2 => "Sep 5"
  | 3 => "Sep 6"
  | _ => "Sep 7"

def dayNumber : Nat → String
  | 0 => "3"
  | 1 => "4"
  | 2 => "5"
  | 3 => "6"
  | _ => "7"

def joinLines (lines : List String) : String :=
  String.intercalate "\n" lines ++ "\n"

def focusMark (actual expected : Focus) : String :=
  if actual == expected then "> " else "  "

def noticeLines (state : State) : List String :=
  if state.notice.isEmpty then [] else ["", "NOTE: " ++ state.notice]

def renderHeader (state : State) : List String :=
  [
    "LOAM UI Prototype 01  [SYNTHETIC / NO WRITES]",
    "Candidate: " ++ candidateName state.candidate,
    "Input model: type a command, then press Enter.",
    ""
  ]

def renderHome (state : State) : String :=
  let candidateCommands :=
    match state.candidate with
    | .hraFlat => "r Record   a Actual   s Scheduled   ? Help   m Switch   z Stats   q Quit"
    | .hybrid => "r Record   / More actions   ? Help   m Switch   z Stats   q Quit"
  joinLines <|
    renderHeader state ++
    [
      "September 2026                 observed through Sep 6",
      "",
      " Mo Tu We Th Fr Sa Su",
      "     1  2  3  4  5 [" ++ dayNumber state.dayIndex ++ "]",
      "",
      "Selected day: " ++ dayLabel state.dayIndex,
      "",
      focusMark state.focus .actual ++ "Actual      coffee      PayPay -> coffee       138 JPY",
      focusMark state.focus .scheduled ++ "Scheduled   Sep 10      bank -> rent       50,000 JPY",
      "",
      "h/l Day   j/k Select row   Enter Open selected",
      candidateCommands
    ] ++ noticeLines state

def renderActualHistory (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Actual history",
      "",
      "> Sep 5   coffee   PayPay -> coffee   138 JPY",
      "",
      "c Correct selected record",
      "b Back"
    ] ++ noticeLines state

def renderScheduledList (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Open Scheduled",
      "",
      "> Sep 10   bank -> rent   50,000 JPY   [scheduled-7]",
      "",
      "r Record what actually happened",
      "e Reschedule / replace",
      "b Back"
    ] ++ noticeLines state

def renderPalette (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "More actions",
      "",
      "Type what you want to do:",
      "  record / purchase",
      "  correct / fix / wrong amount",
      "  scheduled / rent",
      "  reschedule / change scheduled",
      "  help",
      "",
      "b Back"
    ] ++ noticeLines state

def renderRecordDraft (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Record what happened  [MOCK DRAFT]",
      "",
      "Date    [" ++ dayLabel state.dayIndex ++ "]",
      "From    [PayPay]",
      "To      [coffee]",
      "Amount  [138 JPY]",
      "",
      "Nothing is canonical. This prototype cannot write files.",
      "Press Enter to simulate publish, or b to cancel."
    ] ++ noticeLines state

def renderCorrectDraft (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Correct selected Actual  [MOCK DRAFT]",
      "",
      "Original retained fact",
      "  Sep 5   PayPay -> coffee   138 JPY",
      "",
      "Proposed effective replacement",
      "  Sep 5   PayPay -> coffee   150 JPY",
      "",
      "The original would remain in history in real LOAM.",
      "Press Enter to simulate publish, or b to cancel."
    ] ++ noticeLines state

def renderRealizeDraft (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Record Scheduled as Actual  [MOCK DRAFT]",
      "",
      "Scheduled expectation",
      "  Sep 10   bank -> rent   50,000 JPY",
      "",
      "Actual draft defaults",
      "  Date    [" ++ dayLabel state.dayIndex ++ "]",
      "  From    [bank]",
      "  To      [rent]",
      "  Amount  [50,000 JPY]",
      "",
      "Scheduled expectation and Actual evidence remain distinct.",
      "Press Enter to simulate publish, or b to cancel."
    ] ++ noticeLines state

def renderReplaceDraft (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Reschedule / replace  [MOCK DRAFT]",
      "",
      "Current",
      "  Sep 10   bank -> rent   50,000 JPY",
      "",
      "Replacement draft",
      "  Date    [Sep 12]",
      "  From    [bank]",
      "  To      [rent]",
      "  Amount  [50,000 JPY]",
      "",
      "Replacement does not imply continuation or copied routing.",
      "Press Enter to simulate publish, or b to cancel."
    ] ++ noticeLines state

def renderHelp (state : State) : String :=
  let candidateHelp :=
    match state.candidate with
    | .hraFlat =>
        [
          "HRA-flat hypothesis:",
          "  frequent destinations remain directly visible as stable mnemonics.",
          "  Try forgetting the rare Correction path, then rediscover it without using /.",
          "",
          "Home shortcuts: r Record, a Actual, s Scheduled."
        ]
    | .hybrid =>
        [
          "Hybrid hypothesis:",
          "  only frequent actions stay direct; rare actions live behind visible More actions.",
          "  Try typing / then 'wrong amount' after pretending you forgot the command name.",
          "",
          "Home shortcut: r Record. Long tail: / More actions."
        ]
  joinLines <|
    renderHeader state ++
    candidateHelp ++
    [
      "",
      "Shared controls:",
      "  h/l move selected day",
      "  j/k select visible row",
      "  Enter opens selected row",
      "  m switches candidate and returns Home",
      "  z shows structural counters",
      "  b returns from a sub-surface",
      "",
      "b Back"
    ] ++ noticeLines state

def renderMetricRow (name : String) (m : Metrics) : String :=
  name ++
    " commands=" ++ toString m.commands ++
    " palette=" ++ toString m.paletteOpens ++
    " help=" ++ toString m.helpOpens ++
    " unknown=" ++ toString m.unknownCommands ++
    " dayMoves=" ++ toString m.dayMoves ++
    " surfaces=" ++ toString m.surfaceChanges

def renderStats (state : State) : String :=
  joinLines <|
    renderHeader state ++
    [
      "Session structural counters",
      "",
      renderMetricRow "HRA-flat" state.hraMetrics,
      renderMetricRow "Hybrid  " state.hybridMetrics,
      "",
      "These are observations, not usability scores.",
      "Human questions still matter: hesitation, confidence, repeat willingness, avoidance.",
      "",
      "b Back"
    ] ++ noticeLines state

def render (state : State) : String :=
  match state.surface with
  | .home => renderHome state
  | .actualHistory => renderActualHistory state
  | .scheduledList => renderScheduledList state
  | .palette => renderPalette state
  | .recordDraft => renderRecordDraft state
  | .correctDraft => renderCorrectDraft state
  | .realizeDraft => renderRealizeDraft state
  | .replaceDraft => renderReplaceDraft state
  | .help => renderHelp state
  | .stats => renderStats state

def nextFocus : Focus → Focus
  | .none => .actual
  | .actual => .scheduled
  | .scheduled => .actual

def previousFocus : Focus → Focus
  | .none => .scheduled
  | .actual => .scheduled
  | .scheduled => .actual

def unknown (state : State) (command : String) : State :=
  withNotice (countUnknown state) ("Unknown here: '" ++ command ++ "'. Try ? for help.")

def moveDayLeft (state : State) : State :=
  let next := previousDay state.dayIndex
  if next == state.dayIndex then
    withNotice state "Already at the first synthetic day."
  else
    { countDayMove state with dayIndex := next, notice := "" }

def moveDayRight (state : State) : State :=
  let next := nextDay state.dayIndex
  if next == state.dayIndex then
    withNotice state "Already at the last synthetic day."
  else
    { countDayMove state with dayIndex := next, notice := "" }

def handleHome (state : State) (command : String) : State :=
  match command with
  | "h" => moveDayLeft state
  | "l" => moveDayRight state
  | "j" => { state with focus := nextFocus state.focus, notice := "" }
  | "k" => { state with focus := previousFocus state.focus, notice := "" }
  | "" =>
      match state.focus with
      | .none => withNotice state "Select a visible row with j/k before pressing Enter."
      | .actual => goSurface state .actualHistory
      | .scheduled => goSurface state .scheduledList
  | "r" => goSurface state .recordDraft
  | "a" =>
      match state.candidate with
      | .hraFlat => goSurface state .actualHistory
      | .hybrid => unknown state command
  | "s" =>
      match state.candidate with
      | .hraFlat => goSurface state .scheduledList
      | .hybrid => unknown state command
  | "/" =>
      match state.candidate with
      | .hraFlat => unknown state command
      | .hybrid => goSurface (countPaletteOpen state) .palette
  | "?" => goSurface (countHelpOpen state) .help
  | "z" => goSurface state .stats
  | _ => unknown state command

def handleActualHistory (state : State) (command : String) : State :=
  match command with
  | "c" => goSurface state .correctDraft
  | "b" => goSurface state .home
  | "?" => goSurface (countHelpOpen state) .help
  | "/" =>
      match state.candidate with
      | .hybrid => goSurface (countPaletteOpen state) .palette
      | .hraFlat => unknown state command
  | _ => unknown state command

def handleScheduledList (state : State) (command : String) : State :=
  match command with
  | "r" => goSurface state .realizeDraft
  | "e" => goSurface state .replaceDraft
  | "b" => goSurface state .home
  | "?" => goSurface (countHelpOpen state) .help
  | "/" =>
      match state.candidate with
      | .hybrid => goSurface (countPaletteOpen state) .palette
      | .hraFlat => unknown state command
  | _ => unknown state command

def handlePalette (state : State) (command : String) : State :=
  match command with
  | "record" => goSurface state .recordDraft
  | "purchase" => goSurface state .recordDraft
  | "correct" => goSurface state .actualHistory "Palette found: Correct a record."
  | "fix" => goSurface state .actualHistory "Palette found: Correct a record."
  | "wrong amount" => goSurface state .actualHistory "Palette found: Correct a record."
  | "scheduled" => goSurface state .scheduledList
  | "rent" => goSurface state .scheduledList
  | "reschedule" => goSurface state .replaceDraft
  | "change scheduled" => goSurface state .replaceDraft
  | "help" => goSurface (countHelpOpen state) .help
  | "b" => goSurface state .home
  | _ => withNotice (countUnknown state) ("No mock action matches '" ++ command ++ "'.")

def mockPublishNotice : Surface → String
  | .recordDraft => "MOCK ONLY: simulated recording; no file was written."
  | .correctDraft => "MOCK ONLY: simulated append-only correction; no file was written."
  | .realizeDraft => "MOCK ONLY: simulated Scheduled realization; no file was written."
  | .replaceDraft => "MOCK ONLY: simulated Scheduled replacement; no file was written."
  | _ => "MOCK ONLY: no file was written."

def handleDraft (state : State) (command : String) : State :=
  match command with
  | "" => goSurface state .home (mockPublishNotice state.surface)
  | "b" => goSurface state .home "Draft discarded. Canonical data was never touched."
  | _ => unknown state command

def handleHelp (state : State) (command : String) : State :=
  match command with
  | "b" => goSurface state .home
  | _ => unknown state command

def handleStats (state : State) (command : String) : State :=
  match command with
  | "b" => goSurface state .home
  | _ => unknown state command

def switchCandidate (state : State) : State :=
  let next :=
    match state.candidate with
    | .hraFlat => Candidate.hybrid
    | .hybrid => Candidate.hraFlat
  { countSurfaceChange state with
    candidate := next
    surface := .home
    focus := .none
    notice := "Switched candidate. Metrics remain separated by candidate."
  }

def handle (state : State) (command : String) : State :=
  if command == "m" then
    switchCandidate state
  else
    match state.surface with
    | .home => handleHome state command
    | .actualHistory => handleActualHistory state command
    | .scheduledList => handleScheduledList state command
    | .palette => handlePalette state command
    | .recordDraft => handleDraft state command
    | .correctDraft => handleDraft state command
    | .realizeDraft => handleDraft state command
    | .replaceDraft => handleDraft state command
    | .help => handleHelp state command
    | .stats => handleStats state command

def clearScreen : IO Unit :=
  IO.print "\x1b[2J\x1b[H"

def finalSummary (state : State) : String :=
  joinLines [
    "LOAM UI Prototype 01 session summary",
    "",
    renderMetricRow "HRA-flat" state.hraMetrics,
    renderMetricRow "Hybrid  " state.hybridMetrics,
    "",
    "Please compare the candidates with human evidence too:",
    "  1. Where did you hesitate?",
    "  2. Which path could you rediscover after pretending you forgot it?",
    "  3. Was the selected date obvious before mock publication?",
    "  4. Did any extra step feel protective rather than annoying?",
    "  5. Which one would you willingly use again tomorrow?",
    "",
    "No household or canonical data was read or written by this prototype."
  ]

partial def chooseCandidate : IO Candidate := do
  IO.println "LOAM UI Prototype 01"
  IO.println "SYNTHETIC ONLY. This executable does not read or write household data."
  IO.println ""
  IO.println "1  HRA-derived flat"
  IO.println "2  flat + palette hybrid"
  IO.print "> "
  let raw ← IO.getLine
  match raw.trim with
  | "1" => return .hraFlat
  | "2" => return .hybrid
  | _ =>
      IO.println "Choose 1 or 2."
      chooseCandidate

partial def loop (state : State) : IO Unit := do
  clearScreen
  IO.print (render state)
  IO.print "\n> "
  let raw ← IO.getLine
  let command := raw.trim
  if command == "q" then
    IO.println ""
    IO.print (finalSummary state)
  else
    let counted := countCommand state
    loop (handle counted command)

end Loam.Prototype.InteractionShell

def main : IO Unit := do
  let candidate ← Loam.Prototype.InteractionShell.chooseCandidate
  Loam.Prototype.InteractionShell.loop
    (Loam.Prototype.InteractionShell.initialState candidate)
