import Loam.Core.EventCorrectionMemory
import Loam.Core.EventDescription

namespace Loam.Examples.PersonalSemanticMemory

open Loam.Core

set_option autoImplicit false

/-!
# Personal semantic memory experiment

This layer is deliberately outside Core.

It asks whether existing LOAM facts can support the smallest useful conversation
memory operations without introducing a generic profile, knowledge graph, or
"latest fact wins" rule:

- remember one text fact under a stable EventId;
- recall it only when the Event and description are both retained;
- correct it by retaining a replacement Event plus an explicit EventCorrection.

The layer does not choose a current correction frontier. That authority remains
outside this experiment.
-/

/--
A small aggregate of existing Core memories.

This is an experimental composition surface, not new semantic authority.
-/
structure PersonalSemanticMemory where
  events : EventMemory
  descriptions : EventDescriptionMemory
  corrections : EventCorrectionMemory
deriving Repr

def empty : PersonalSemanticMemory :=
  { events := { events := [], idNodup := by simp }
    descriptions := EventDescriptionMemory.empty
    corrections := { corrections := [], idNodup := by simp } }

/--
A text-only remembered fact is an Event with no quantity Effects.

The text remains separate Event-scoped descriptive evidence.
-/
def textEvent (id : EventId) : Event :=
  { id := id
    effects := []
    keyNodup := by simp [retainedEffectKeys] }

/--
Remember one fresh text fact.

Because the operation is pure, failure leaves the caller's original memory
unchanged. Duplicate Event identity or duplicate description identity is
rejected by the existing Core memories.
-/
def remember?
    (memory : PersonalSemanticMemory)
    (id : EventId)
    (text : String) : Option PersonalSemanticMemory := do
  let events ← EventMemory.add? memory.events (textEvent id)
  let descriptions ←
    EventDescriptionMemory.add? memory.descriptions { event := id, text := text }
  return
    { events := events
      descriptions := descriptions
      corrections := memory.corrections }

/--
Recall text only when the corresponding Event identity is also retained.

This prevents an orphan description from being treated as a remembered fact.
No correction or "latest" semantics are applied here.
-/
def recall?
    (memory : PersonalSemanticMemory)
    (id : EventId) : Option String := do
  let _ ← EventMemory.findById? memory.events id
  EventDescriptionMemory.findText? memory.descriptions id

/--
Retain a corrected interpretation of one remembered text fact.

The target must already exist. The replacement identity must be fresh because it
is first admitted through remember?. The original Event and description remain
retained. This function records only the explicit correction edge; it does not
declare the replacement globally current or latest.
-/
def correct?
    (memory : PersonalSemanticMemory)
    (target replacement : EventId)
    (replacementText : String) : Option PersonalSemanticMemory := do
  let _ ← EventMemory.findById? memory.events target
  let remembered ← remember? memory replacement replacementText
  let corrections ←
    EventCorrectionMemory.add? remembered.corrections
      { target := target, replacement := replacement }
  return
    { events := remembered.events
      descriptions := remembered.descriptions
      corrections := corrections }

/--
Inspect one explicitly supplied correction only when that exact correction fact
is retained and both endpoint descriptions can be recalled.

The caller names the correction to inspect. List position is not interpreted as
time or authority.
-/
def recallCorrection?
    (memory : PersonalSemanticMemory)
    (correction : EventCorrection) : Option (String × String) := do
  if correction ∈ memory.corrections.corrections then
    let closed ← EventCorrection.project? memory.events correction
    let originalText ← recall? memory closed.original.id
    let replacementText ← recall? memory closed.effective.id
    return (originalText, replacementText)
  else
    none

namespace Example

def note1 : EventId := ⟨"memory:note-1"⟩
def note2 : EventId := ⟨"memory:note-2"⟩

def remembered : Option PersonalSemanticMemory :=
  remember? empty note1 "editor preference: nvim"

def corrected : Option PersonalSemanticMemory := do
  let memory ← remembered
  correct? memory note1 note2 "editor preference: nvim; configuration may evolve"

/-- A freshly remembered text fact can be recalled by stable identity. -/
theorem remember_then_recall :
    remembered.bind (fun memory => recall? memory note1) =
      some "editor preference: nvim" := by
  simp [remembered, remember?, recall?, empty, note1, textEvent,
    EventMemory.add?, EventMemory.ofEvents?, EventMemory.findById?,
    EventDescriptionMemory.add?, EventDescriptionMemory.ofEntries?,
    EventDescriptionMemory.findText?, FiniteKeyed.findBy?,
    retainedEffectKeys]

/-- Remembering the same identity twice is rejected rather than overwritten. -/
theorem duplicate_remember_is_rejected :
    remembered.bind
      (fun memory => remember? memory note1 "different text") = none := by
  simp [remembered, remember?, empty, note1, textEvent,
    EventMemory.add?, EventMemory.ofEvents?, retainedEffectKeys]

/--
Correction preserves the original text, adds the replacement text, and retains
an explicit note1 -> note2 correction edge.
-/
theorem correction_is_explicit_and_non_destructive :
    corrected.bind
      (fun memory =>
        recallCorrection? memory { target := note1, replacement := note2 }) =
      some
        ("editor preference: nvim",
         "editor preference: nvim; configuration may evolve") := by
  simp [corrected, remembered, correct?, remember?, recallCorrection?, recall?,
    empty, note1, note2, textEvent, EventMemory.add?, EventMemory.ofEvents?,
    EventMemory.findById?, EventDescriptionMemory.add?,
    EventDescriptionMemory.ofEntries?, EventDescriptionMemory.findText?,
    EventCorrectionMemory.add?, EventCorrectionMemory.ofCorrections?,
    EventCorrection.project?, FiniteKeyed.findBy?, retainedEffectKeys]

end Example

end Loam.Examples.PersonalSemanticMemory
