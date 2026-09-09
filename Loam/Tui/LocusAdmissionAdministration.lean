import Loam.LocusAdmissionPublisher
import Loam.LocusCatalog
import Loam.Persistence
import Loam.Tui.Kernel
import Loam.Tui.Layout
import Loam.Tui.Terminal

namespace Loam.Tui.LocusAdmissionAdministration

open Loam.Core
open Loam.Tui.Kernel
open Loam.Tui.Layout
open Loam.Tui.Terminal

set_option autoImplicit false

/-!
# Locus admission administration

Add-only presentation over the current admitted picker catalog. The catalog is
used to make existing identities visible before a new stable token is proposed;
it does not grant write authority. Publication is delegated to the shared
`LocusAdmissionPublisher`.

The terminal session may open separate initial AccountingRole administration
with Tab. This view itself still owns no role semantics or role write authority.
-/

inductive Phase where
  | editing
  | preview
  deriving Repr, DecidableEq

structure State where
  catalog : Loam.LocusCatalog.Catalog
  entered : String := ""
  phase : Phase := .editing
  scroll : Nat := 0
  notice : String := ""
  deriving Repr

structure Step where
  state : State
  cancel : Bool := false
  publish : Option Loam.LocusAdmissionPublisher.Draft := none
  deriving Repr


def initial (catalog : Loam.LocusCatalog.Catalog) : State :=
  { catalog := catalog }

private def validation? (state : State) : Except String Loam.LocusAdmissionPublisher.Draft := do
  if state.entered.isEmpty then
    throw "Enter one new stable Locus token."
  if !Loam.Persistence.validToken state.entered then
    throw "Locus token is not valid canonical token syntax."
  if (Loam.LocusCatalog.exactToken? state.catalog state.entered).isSome then
    throw "That Locus is already admitted. Choose the existing identity instead."
  pure { token := state.entered }


def draft? (state : State) : Option Loam.LocusAdmissionPublisher.Draft :=
  match validation? state with
  | .ok draft => some draft
  | .error _ => none

private def clampScroll (state : State) : Nat :=
  if state.catalog.isEmpty then 0 else min state.scroll (state.catalog.length - 1)


def update (state : State) (key : Key) : Step :=
  match state.phase with
  | .editing =>
      match key with
      | .escape => { state := state, cancel := true }
      | .up =>
          let next := if state.scroll == 0 then 0 else state.scroll - 1
          { state := { state with scroll := next, notice := "" } }
      | .down =>
          let next := if state.scroll + 1 < state.catalog.length then state.scroll + 1 else state.scroll
          { state := { state with scroll := next, notice := "" } }
      | .backspace =>
          { state := { state with
              entered := String.ofList state.entered.toList.dropLast
              notice := "" } }
      | .enter =>
          match validation? state with
          | .ok _ => { state := { state with phase := .preview, notice := "" } }
          | .error message => { state := { state with notice := message } }
      | .input char =>
          { state := { state with entered := state.entered.push char, notice := "" } }
      | _ => { state := state }
  | .preview =>
      match key with
      | .enter =>
          match validation? state with
          | .ok draft => { state := state, publish := some draft }
          | .error message => { state := { state with phase := .editing, notice := message } }
      | .escape | .backspace | .input 'e' | .input 'E' =>
          { state := { state with phase := .editing, notice := "" } }
      | _ => { state := state }

private def line (text : String) : Widget := .row [span text]
private def muted (text : String) : Widget := .row [span text .muted]
private def blank : Widget := line ""

private def displayEntry (entry : Loam.LocusCatalog.Entry) : String :=
  if entry.label == entry.locus.token then entry.locus.token
  else padRight 28 entry.locus.token ++ entry.label

private def visibleEntries (bounds : Bounds) (state : State) : List (Nat × Loam.LocusCatalog.Entry) :=
  let maxVisible := if bounds.height > 14 then min 12 (bounds.height - 12) else 5
  let selected := clampScroll state
  let start :=
    if state.catalog.length <= maxVisible then 0
    else if selected + 1 <= maxVisible then 0
    else min (selected + 1 - maxVisible) (state.catalog.length - maxVisible)
  (state.catalog.drop start |>.take maxVisible).zipIdx.map fun (entry, index) =>
    (start + index, entry)

private def catalogRows (bounds : Bounds) (state : State) : List Widget :=
  if state.catalog.isEmpty then [muted "   (no Locus is currently admitted)"]
  else
    (visibleEntries bounds state).map fun (index, entry) =>
      let selected := index == clampScroll state
      .row [span ((if selected then "▶  " else "   ") ++ displayEntry entry)
        (if selected then .selected else .normal)]


def view (bounds : Bounds) (state : State) : Widget :=
  match state.phase with
  | .editing =>
      .column <|
        [ line "Locus Administration / Admit New Identity"
        , muted "New-write permission only"
        , blank
        , muted ("Currently admitted: " ++ toString state.catalog.length)
        , muted "Review the existing vocabulary before creating another identity."
        , blank
        , muted ("   " ++ padRight 28 "Stable token" ++ "Display label")
        ] ++ catalogRows bounds state ++
        [ blank
        , line ("New stable token: " ++ state.entered ++ "_")
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter preview   Backspace edit   ↑/↓ inspect existing   Tab initial roles   Esc cancel"
        , muted "Admission itself does not create a label, AccountingRole, Purpose route, rename, or alias."
        ]
  | .preview =>
      .column
        [ line "Locus Administration / Preview"
        , muted "Add one new-write permission"
        , blank
        , line ("Stable token: " ++ state.entered)
        , line ("Current admitted count: " ++ toString state.catalog.length)
        , line ("After publication: " ++ toString (state.catalog.length + 1))
        , blank
        , muted "This changes only LocusAdmission in the Movement generation."
        , muted "No display label, AccountingRole, Purpose routing, rename, or historical rewrite is created."
        , blank
        , if state.notice.isEmpty then blank else line state.notice
        , muted "Enter publish   e/E or Esc edit"
        ]

end Loam.Tui.LocusAdmissionAdministration
