import Loam.Core.EventDescription

namespace Loam.Examples.DocumentProvenanceBoundary

open Loam.Core

set_option autoImplicit false

/-!
# Non-household Core boundary probe: document provenance

This probe removes quantity entirely.

Current Core can retain quantity-free Event identities and Event-scoped
descriptions. What it does *not* currently provide is a generic semantic edge
for "derived from". EventCorrection is intentionally not reused for that
purpose because correction and derivation have different meanings: a derived
document may remain valid alongside its source.

The tiny DocumentDerivation structure below is therefore local to this
example. Its presence is the observed boundary, not a proposed Core change.
-/

def sourceId : EventId := ⟨"document:source-a"⟩
def derivedId : EventId := ⟨"document:derived-b"⟩

/-- A document identity can be retained as an Event with no quantity Effects. -/
def sourceDocument : Event :=
  { id := sourceId
    effects := []
    keyNodup := by simp [retainedEffectKeys] }

/-- The derived document is likewise quantity-free. -/
def derivedDocument : Event :=
  { id := derivedId
    effects := []
    keyNodup := by simp [retainedEffectKeys] }

def documents : EventMemory :=
  { events := [sourceDocument, derivedDocument]
    idNodup := by
      simp [sourceDocument, derivedDocument, sourceId, derivedId] }

def descriptions : EventDescriptionMemory :=
  { entries :=
      [ { event := sourceId, text := "source document A" }
      , { event := derivedId, text := "derived document B" }
      ]
    eventNodup := by
      simp [sourceId, derivedId] }

/--
This relation is deliberately example-local.

If LOAM already had a generic provenance edge with the intended semantics, this
extra structure would be unnecessary. EventCorrection is not substituted:
"derived from" does not claim that the source document's interpretation is
corrected or superseded.
-/
structure DocumentDerivation where
  source : EventId
  derived : EventId
deriving Repr, DecidableEq

def derivation : DocumentDerivation :=
  { source := sourceId
    derived := derivedId }

structure ClosedDocumentDerivation where
  edge : DocumentDerivation
  source : Event
  derived : Event

namespace DocumentDerivation

/-- Close the local provenance edge only when both endpoint Events are retained. -/
def project? (memory : EventMemory) (edge : DocumentDerivation) :
    Option ClosedDocumentDerivation := do
  let source ← EventMemory.findById? memory edge.source
  let derived ← EventMemory.findById? memory edge.derived
  return { edge := edge, source := source, derived := derived }

end DocumentDerivation

/-- Quantity is genuinely absent from both document Events. -/
theorem documents_have_no_effects :
    sourceDocument.effects = [] ∧ derivedDocument.effects = [] := by
  rfl

/-- Event identity remains usable without any Effect / Measure / Quantity value. -/
theorem source_identity_is_retained :
    EventMemory.findById? documents sourceId = some sourceDocument := by
  simp [documents, sourceDocument, derivedDocument, sourceId, derivedId,
    EventMemory.findById?, FiniteKeyed.findBy?]

/-- Human recognition text also remains available without quantity facts. -/
theorem source_description_is_retained :
    EventDescriptionMemory.findText? descriptions sourceId =
      some "source document A" := by
  simp [EventDescriptionMemory.findText?, descriptions, sourceId, derivedId,
    FiniteKeyed.findBy?]

/--
Once the missing provenance meaning is supplied locally, endpoint closure needs
only the existing EventMemory machinery.
-/
theorem local_derivation_projects :
    (DocumentDerivation.project? documents derivation).isSome = true := by
  simp [DocumentDerivation.project?, documents, derivation,
    EventMemory.findById?, FiniteKeyed.findBy?, sourceDocument,
    derivedDocument, sourceId, derivedId]

end Loam.Examples.DocumentProvenanceBoundary
