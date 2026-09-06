import Std

namespace Loam.Prototype.InteractionShellMain

set_option autoImplicit false

inductive Candidate where
  | hraFlat
  | hybrid
  deriving Repr, DecidableEq, BEq

inductive Surface where
  | home
  | actual
  | scheduled
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
  commands : Nat := 0
  paletteOpens : Nat := 0
  helpOpens : Nat := 0
  unknownCommands : Nat := 0
  dayMoves : Nat := 0
  surfaceChanges : Nat := 0
  deriving Repr

structure State where
  candidate : Candidate
  surface : Surface := .home
  dayIndex : Nat := 3
  focus : Focus := .none
  hra : Metrics := {}
  hybrid : Metrics := {}
  notice : String := ""
  deriving Repr

def candidateName : Candidate → String
  | .hraFlat => "HRA-derived flat"
  | .hybrid => "flat + palette hybrid"

def selectedDay : Nat → String
  | 0 => "Sep 3"
  | 1 => "Sep 4"
  | 2 => "Sep 5"
  | 3 => "Sep 6"
  | _ => "Sep 7"

def selectedDayNumber : Nat → String
  | 0 => "3"
  | 1 => "4"
  | 2 => "5"
  | 3 => "6"
  | _ => "7"

def updateMetrics (state : State) (f : Metrics → Metrics) : State :=
  match state.candidate with
  | .hraFlat => { state with hra := f state.hra }
  | .hybrid => { state with hybrid := f state.hybrid }

def countCommand (state : State) : State :=
  updateMetrics state fun m => { m with commands := m.commands + 1 }

def countPalette (state : State) : State :=
  updateMetrics state fun m => { m with paletteOpens := m.paletteOpens + 1 }

def countHelp (state : State) : State :=
  updateMetrics state fun m => { m with helpOpens := m.helpOpens + 1 }

def countUnknown (state : State) : State :=
  updateMetrics state fun m => { m with unknownCommands := m.unknownCommands + 1 }

def countDayMove (state : State) : State :=
  updateMetrics state fun m => { m with dayMoves := m.dayMoves + 1 }

def countSurface (state : State) : State :=
  updateMetrics state fun m => { m with surfaceChanges := m.surfaceChanges + 1 }

def go (state : State) (surface : Surface) (notice : String := "") : State :=
  let state := if state.surface == surface then state else countSurface state
  { state with surface := surface, focus := .none, notice := notice }

def unknown (state : State) (input : String) : State :=
  { countUnknown state with notice := "Unknown here: '" ++ input ++ "'. Try ? for help." }

def lines (xs : List String) : String :=
  String.intercalate "\n" xs ++ "\n"

def header (state : State) : List String :=
  [
    "LOAM UI Prototype 01  [SYNTHETIC / NO WRITES]",
    "Candidate: " ++ candidateName state.candidate,
    "Type a command and press Enter.",
    ""
  ]

def addNotice (state : State) (xs : List String) : List String :=
  if state.notice.isEmpty then xs else xs ++ ["", "NOTE: " ++ state.notice]

def focusPrefix (state : State) (focus : Focus) : String :=
  if state.focus == focus then "> " else "  "

def renderHome (state : State) : String :=
  let footer :=
    match state.candidate with
    | .hraFlat => "r Record   a Actual   s Scheduled   ? Help   m Switch   z Stats   q Quit"
    | .hybrid => "r Record   / More actions   ? Help   m Switch   z Stats   q Quit"
  lines <| addNotice state <| header state ++ [
    "September 2026                 observed through Sep 6",
    "",
    " Mo Tu We Th Fr Sa Su",
    "     1  2  3  4  5 [" ++ selectedDayNumber state.dayIndex ++ "]",
    "",
    "Selected day: " ++ selectedDay state.dayIndex,
    "",
    focusPrefix state .actual ++ "Actual      coffee      PayPay -> coffee       138 JPY",
    focusPrefix state .scheduled ++ "Scheduled   Sep 10      bank -> rent       50,000 JPY",
    "",
    "h/l Day   j/k Select row   Enter Open selected",
    footer
  ]

def renderActual (state : State) : String :=
  lines <| addNotice state <| header state ++ [
    "Actual history",
    "",
    "> Sep 5   coffee   PayPay -> coffee   138 JPY",
    "",
    "c Correct selected record",
    "b Back"
  ]

def renderScheduled (state : State) : String :=
  lines <| addNotice state <| header state ++ [
    "Open Scheduled",
    "",
    "> Sep 10   bank -> rent   50,000 JPY   [scheduled-7]",
    "",
    "r Record what actually happened",
    "e Reschedule / replace",
    "b Back"
  ]

def renderPalette (state : State) : String :=
  lines <| addNotice state <| header state ++ [
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
  ]

def renderRecordDraft (state : State) : String :=
  lines <| header state ++ [
    "Record what happened  [MOCK DRAFT]",
    "",
    "Date    [" ++ selectedDay state.dayIndex ++ "]",
    "From    [PayPay]",
    "To      [coffee]",
    "Amount  [138 JPY]",
    "",
    "Nothing is canonical. This prototype cannot write files.",
    "Press Enter to simulate publish, or b to cancel."
  ]

def renderCorrectDraft (state : State) : String :=
  lines <| header state ++ [
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
  ]

def renderRealizeDraft (state : State) : String :=
  lines <| header state ++ [
    "Record Scheduled as Actual  [MOCK DRAFT]",
    "",
    "Scheduled expectation",
    "  Sep 10   bank -> rent   50,000 JPY",
    "",
    "Actual draft defaults",
    "  Date    [" ++ selectedDay state.dayIndex ++ "]",
    "  From    [bank]",
    "  To      [rent]",
    "  Amount  [50,000 JPY]",
    "",
    "Scheduled expectation and Actual evidence remain distinct.",
    "Press Enter to simulate publish, or b to cancel."
  ]

def renderReplaceDraft (state : State) : String :=
  lines <| header state ++ [
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
  ]

def renderHelp (state : State) : String :=
  let candidateText :=
    match state.candidate with
    | .hraFlat => [
        "HRA-flat: frequent destinations stay directly visible.",
        "Home shortcuts: r Record, a Actual, s Scheduled.",
        "Try rediscovering rare Correction without a palette."
      ]
    | .hybrid => [
        "Hybrid: frequent actions stay direct; rare actions use More actions.",
        "Try / then 'wrong amount' after pretending you forgot Correction."
      ]
  lines <| header state ++ candidateText ++ [
    "",
    "Shared: h/l day, j/k row, Enter open, m switch, z stats, b back.",
    "b Back"
  ]

def metricLine (name : String) (m : Metrics) : String :=
  name ++
    " commands=" ++ toString m.commands ++
    " palette=" ++ toString m.paletteOpens ++
    " help=" ++ toString m.helpOpens ++
    " unknown=" ++ toString m.unknownCommands ++
    " dayMoves=" ++ toString m.dayMoves ++
    " surfaces=" ++ toString m.surfaceChanges

def renderStats (state : State) : String :=
  lines <| header state ++ [
    "Session structural counters",
    "",
    metricLine "HRA-flat" state.hra,
    metricLine "Hybrid  " state.hybrid,
    "",
    "Counters are observations, not usability scores.",
    "b Back"
  ]

def render (state : State) : String :=
  match state.surface with
  | .home => renderHome state
  | .actual => renderActual state
  | .scheduled => renderScheduled state
  | .palette => renderPalette state
  | .recordDraft => renderRecordDraft state
  | .correctDraft => renderCorrectDraft state
  | .realizeDraft => renderRealizeDraft state
  | .replaceDraft => renderReplaceDraft state
  | .help => renderHelp state
  | .stats => renderStats state

def moveLeft (state : State) : State :=
  if state.dayIndex == 0 then
    { state with notice := "Already at the first synthetic day." }
  else
    { countDayMove state with dayIndex := state.dayIndex - 1, notice := "" }

def moveRight (state : State) : State :=
  if state.dayIndex >= 4 then
    { state with notice := "Already at the last synthetic day." }
  else
    { countDayMove state with dayIndex := state.dayIndex + 1, notice := "" }

def nextFocus : Focus → Focus
  | .none => .actual
  | .actual => .scheduled
  | .scheduled => .actual

def previousFocus : Focus → Focus
  | .none => .scheduled
  | .actual => .scheduled
  | .scheduled => .actual

def handleHome (state : State) (input : String) : State :=
  match input with
  | "h" => moveLeft state
  | "l" => moveRight state
  | "j" => { state with focus := nextFocus state.focus, notice := "" }
  | "k" => { state with focus := previousFocus state.focus, notice := "" }
  | "" =>
      match state.focus with
      | .none => { state with notice := "Select a visible row with j/k before pressing Enter." }
      | .actual => go state .actual
      | .scheduled => go state .scheduled
  | "r" => go state .recordDraft
  | "a" => if state.candidate == .hraFlat then go state .actual else unknown state input
  | "s" => if state.candidate == .hraFlat then go state .scheduled else unknown state input
  | "/" => if state.candidate == .hybrid then go (countPalette state) .palette else unknown state input
  | "?" => go (countHelp state) .help
  | "z" => go state .stats
  | _ => unknown state input

def handleActual (state : State) (input : String) : State :=
  match input with
  | "c" => go state .correctDraft
  | "b" => go state .home
  | "/" => if state.candidate == .hybrid then go (countPalette state) .palette else unknown state input
  | "?" => go (countHelp state) .help
  | _ => unknown state input

def handleScheduled (state : State) (input : String) : State :=
  match input with
  | "r" => go state .realizeDraft
  | "e" => go state .replaceDraft
  | "b" => go state .home
  | "/" => if state.candidate == .hybrid then go (countPalette state) .palette else unknown state input
  | "?" => go (countHelp state) .help
  | _ => unknown state input

def handlePalette (state : State) (input : String) : State :=
  match input with
  | "record" | "purchase" => go state .recordDraft
  | "correct" | "fix" | "wrong amount" => go state .actual "Palette found: Correct a record."
  | "scheduled" | "rent" => go state .scheduled
  | "reschedule" | "change scheduled" => go state .replaceDraft
  | "help" => go (countHelp state) .help
  | "b" => go state .home
  | _ => { countUnknown state with notice := "No mock action matches '" ++ input ++ "'." }

def mockNotice : Surface → String
  | .recordDraft => "MOCK ONLY: simulated recording; no file was written."
  | .correctDraft => "MOCK ONLY: simulated append-only correction; no file was written."
  | .realizeDraft => "MOCK ONLY: simulated Scheduled realization; no file was written."
  | .replaceDraft => "MOCK ONLY: simulated Scheduled replacement; no file was written."
  | _ => "MOCK ONLY: no file was written."

def isDraft : Surface → Bool
  | .recordDraft | .correctDraft | .realizeDraft | .replaceDraft => true
  | _ => false

def switchCandidate (state : State) : State :=
  let next := if state.candidate == .hraFlat then Candidate.hybrid else Candidate.hraFlat
  { countSurface state with
    candidate := next
    surface := .home
    focus := .none
    notice := "Switched candidate. Metrics remain separated by candidate."
  }

def handle (state : State) (input : String) : State :=
  if input == "m" then
    switchCandidate state
  else if isDraft state.surface then
    if input.isEmpty then go state .home (mockNotice state.surface)
    else if input == "b" then go state .home "Draft discarded. Canonical data was never touched."
    else unknown state input
  else
    match state.surface with
    | .home => handleHome state input
    | .actual => handleActual state input
    | .scheduled => handleScheduled state input
    | .palette => handlePalette state input
    | .help => if input == "b" then go state .home else unknown state input
    | .stats => if input == "b" then go state .home else unknown state input
    | _ => state

def clear : IO Unit :=
  IO.print "\x1b[2J\x1b[H"

def promptLine : IO String := do
  IO.print "> "
  (← IO.getStdout).flush
  let stdin ← IO.getStdin
  return (← stdin.getLine).trimAsciiEnd.toString

def summary (state : State) : String :=
  lines [
    "LOAM UI Prototype 01 session summary",
    "",
    metricLine "HRA-flat" state.hra,
    metricLine "Hybrid  " state.hybrid,
    "",
    "1. Where did you hesitate?",
    "2. Which path could you rediscover after pretending you forgot it?",
    "3. Was the selected date obvious before mock publication?",
    "4. Did any extra step feel protective rather than annoying?",
    "5. Which one would you willingly use again tomorrow?",
    "",
    "No household or canonical data was read or written by this prototype."
  ]

partial def chooseCandidate : IO Candidate := do
  IO.println "LOAM UI Prototype 01"
  IO.println "SYNTHETIC ONLY. This executable does not read or write household data."
  IO.println ""
  IO.println "1  HRA-derived flat"
  IO.println "2  flat + palette hybrid"
  let input ← promptLine
  match input with
  | "1" => return .hraFlat
  | "2" => return .hybrid
  | _ =>
      IO.println "Choose 1 or 2."
      chooseCandidate

partial def loop (state : State) : IO Unit := do
  clear
  IO.print (render state)
  let input ← promptLine
  if input == "q" then
    IO.println ""
    IO.print (summary state)
  else
    loop (handle (countCommand state) input)

end Loam.Prototype.InteractionShellMain

def main : IO Unit := do
  let candidate ← Loam.Prototype.InteractionShellMain.chooseCandidate
  Loam.Prototype.InteractionShellMain.loop { candidate := candidate }
