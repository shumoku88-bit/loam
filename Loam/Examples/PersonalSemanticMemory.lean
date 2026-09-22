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
  return {
    events := events
    descriptions := descriptions
    corrections := memory.corrections
  }

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
  return {
    events := remembered.events
    descriptions := remembered.descriptions
    corrections := corrections
  }

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

def rememberedMemory : PersonalSemanticMemory :=
  { events :=
      { events := [textEvent note1]
        idNodup := by simp }
    descriptions :=
      { entries :=
          [{ event := note1, text := "editor preference: nvim" }]
        eventNodup := by simp }
    corrections :=
      { corrections := []
        idNodup := by simp } }

def noteCorrection : EventCorrection :=
  { target := note1
    replacement := note2 }

def correctedMemory : PersonalSemanticMemory :=
  { events :=
      { events := [textEvent note1, textEvent note2]
        idNodup := by simp [textEvent, note1, note2] }
    descriptions :=
      { entries :=
          [ { event := note1, text := "editor preference: nvim" }
          , { event := note2,
              text := "editor preference: nvim; configuration may evolve" }
          ]
        eventNodup := by simp [note1, note2] }
    corrections :=
      { corrections := [noteCorrection]
        idNodup := by simp } }

/-- A retained text fact is recalled by stable identity. -/
theorem recall_retained_fact :
    recall? rememberedMemory note1 = some "editor preference: nvim" := by
  simp [recall?, rememberedMemory, note1, textEvent,
    EventMemory.findById?, EventDescriptionMemory.findText?,
    FiniteKeyed.findBy?]

/-- Reusing the same EventId is rejected rather than treated as an overwrite. -/
theorem duplicate_remember_is_rejected :
    remember? rememberedMemory note1 "different text" = none := by
  simp [remember?, rememberedMemory, note1, textEvent,
    EventMemory.add?_singleton_duplicate]

/--
An explicit correction keeps both texts inspectable; it does not erase the
original retained fact.
-/
theorem correction_is_explicit_and_non_destructive :
    recallCorrection? correctedMemory noteCorrection =
      some
        ("editor preference: nvim",
         "editor preference: nvim; configuration may evolve") := by
  simp [recallCorrection?, correctedMemory, noteCorrection, recall?,
    note1, note2, textEvent, EventCorrection.project?,
    EventMemory.findById?, EventDescriptionMemory.findText?,
    FiniteKeyed.findBy?]

end Example

end Loam.Examples.PersonalSemanticMemory
