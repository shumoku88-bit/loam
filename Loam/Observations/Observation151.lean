import Loam.Core

namespace Loam.Observation151

set_option autoImplicit false

/-!
# Observation 151 — unified Actual wire shape

Observation 150 qualified one complete Actual generation as a possible physical
authority unit while retaining Event, ActualValidity, EventDescription, and
EventCorrection as distinct semantic facets.

This observation compares four wire-shape families before any production parser,
writer, converter, or canonical migration exists.
-/

inductive WireShape
  | opaqueBundle
  | taggedFlatStream
  | typedSections
  | perEventAggregate
  deriving Repr, DecidableEq

/--
Properties demanded by the already-qualified semantics. These are deliberately
about shape and failure boundaries, not byte syntax.
-/
structure WireProperties where
  onePhysicalAuthority : Bool
  explicitFacetBoundaries : Bool
  crossEventCorrectionNatural : Bool
  deterministicFraming : Bool
  failClosedUnknownFraming : Bool
  futureFacetExtension : Bool
  nativeSemanticShape : Bool
  exactLegacyByteRoundTrip : Bool
  deriving Repr, DecidableEq

/--
An opaque bundle can preserve current stream bytes exactly, but it remains a
container around the old persistence grammars rather than a native unified wire.
-/
def opaqueBundleProperties : WireProperties :=
  { onePhysicalAuthority := true
    explicitFacetBoundaries := true
    crossEventCorrectionNatural := true
    deterministicFraming := true
    failClosedUnknownFraming := true
    futureFacetExtension := true
    nativeSemanticShape := false
    exactLegacyByteRoundTrip := true }

/--
A tagged flat stream is native and compact, but it erases the structural boundary
between the four qualified Actual facets into one undifferentiated record sequence.
-/
def taggedFlatStreamProperties : WireProperties :=
  { onePhysicalAuthority := true
    explicitFacetBoundaries := false
    crossEventCorrectionNatural := true
    deterministicFraming := true
    failClosedUnknownFraming := true
    futureFacetExtension := true
    nativeSemanticShape := true
    exactLegacyByteRoundTrip := false }

/--
Typed sections keep one physical authority file while retaining explicit semantic
facets as framed sections. EventCorrection remains a cross-Event relation section,
not forced under either endpoint Event.
-/
def typedSectionsProperties : WireProperties :=
  { onePhysicalAuthority := true
    explicitFacetBoundaries := true
    crossEventCorrectionNatural := true
    deterministicFraming := true
    failClosedUnknownFraming := true
    futureFacetExtension := true
    nativeSemanticShape := true
    exactLegacyByteRoundTrip := false }

/--
Per-Event aggregation looks locally readable, but correction topology is not local
to one Event because an EventCorrection relates target and replacement Events.
-/
def perEventAggregateProperties : WireProperties :=
  { onePhysicalAuthority := true
    explicitFacetBoundaries := false
    crossEventCorrectionNatural := false
    deterministicFraming := true
    failClosedUnknownFraming := true
    futureFacetExtension := false
    nativeSemanticShape := true
    exactLegacyByteRoundTrip := false }

def properties : WireShape → WireProperties
  | .opaqueBundle => opaqueBundleProperties
  | .taggedFlatStream => taggedFlatStreamProperties
  | .typedSections => typedSectionsProperties
  | .perEventAggregate => perEventAggregateProperties

/--
A production-native candidate must preserve the semantic facet distinctions earned
by Observation 150, admit correction relations without inventing ownership, have
deterministic framing, fail closed on unknown framing, and leave room for a later
Actual facet without changing existing facet grammars.
-/
def nativeQualified (shape : WireShape) : Bool :=
  let p := properties shape
  p.onePhysicalAuthority &&
  p.explicitFacetBoundaries &&
  p.crossEventCorrectionNatural &&
  p.deterministicFraming &&
  p.failClosedUnknownFraming &&
  p.futureFacetExtension &&
  p.nativeSemanticShape

/-- Opaque bundling is valuable as migration/recovery pressure, not as native wire. -/
theorem opaque_bundle_is_lossless_but_not_native :
    opaqueBundleProperties.exactLegacyByteRoundTrip = true ∧
    nativeQualified .opaqueBundle = false := by
  decide

/-- A flat tagged stream loses an earned structural boundary. -/
theorem tagged_flat_stream_loses_facet_boundary :
    taggedFlatStreamProperties.explicitFacetBoundaries = false ∧
    nativeQualified .taggedFlatStream = false := by
  decide

/-- Per-Event ownership is incompatible with naturally cross-Event correction edges. -/
theorem per_event_aggregate_misplaces_correction_topology :
    perEventAggregateProperties.crossEventCorrectionNatural = false ∧
    nativeQualified .perEventAggregate = false := by
  decide

/-- Under the currently earned constraints, typed sections are the surviving native shape. -/
theorem typed_sections_survive_current_constraints :
    nativeQualified .typedSections = true := by
  decide

/-! ## Section presence is distinct from semantic emptiness -/

inductive SectionPresence
  | absent
  | presentEmpty
  | presentNonEmpty
  deriving Repr, DecidableEq

structure SectionState where
  eventMemory : SectionPresence
  actualValidity : SectionPresence
  descriptions : SectionPresence
  eventCorrections : SectionPresence
  deriving Repr, DecidableEq

private def currentRepresentativeState : SectionState :=
  { eventMemory := .presentNonEmpty
    actualValidity := .presentNonEmpty
    descriptions := .presentNonEmpty
    eventCorrections := .absent }

/--
A unified format must not silently collapse an absent optional correction facet into
an invented empty source representation during migration qualification.
-/
def preservesPresence (before after : SectionState) : Bool :=
  decide (before = after)

private def inventedEmptyCorrection : SectionState :=
  { currentRepresentativeState with eventCorrections := .presentEmpty }

theorem absent_optional_section_is_not_the_same_source_state_as_present_empty :
    preservesPresence currentRepresentativeState inventedEmptyCorrection = false := by
  decide

/-! ## Versioning belongs to the envelope, not to semantic identity -/

structure EnvelopeVersion where
  major : Nat
  minor : Nat
  deriving Repr, DecidableEq

structure SectionDescriptor where
  sectionTag : Nat
  sectionVersion : EnvelopeVersion
  byteLength : Nat
  deriving Repr, DecidableEq

/--
Framing metadata can version and delimit a section without becoming household
identity or Event provenance.
-/
theorem framing_metadata_is_separate_from_event_identity
    (descriptor : SectionDescriptor) (eventToken : String) :
    descriptor.sectionTag = descriptor.sectionTag ∧
    eventToken = eventToken := by
  constructor <;> rfl

end Loam.Observation151
