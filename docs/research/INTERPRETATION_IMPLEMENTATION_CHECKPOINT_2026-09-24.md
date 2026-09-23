# Interpretation implementation checkpoint — 2026-09-24

Status: **IMPLEMENTATION READY — NO PRODUCTION CODE IN THIS CHECKPOINT**

## 1. What is now qualified

Observations 320–327 converged on a small interpretation-evidence boundary.

### Retained meaning

```text
note identity
interpretive text
historical subject EventId
recordedAt
optional attributedAt
```

### Derived meaning

```text
currentSubject
```

`currentSubject` is never persisted. It is derived from the retained historical
subject through the admitted EventCorrection frontier.

### Not retained

There is no singleton "current interpretation" field.

Multiple later interpretations of the same subject may coexist, including
interpretations that disagree.

Absence of `attributedAt` is meaningful and must not be defaulted to Fact time
or recording time.

## 2. Reuse boundary

The first implementation should **not** introduce a parallel Reflection object
containing identity and text.

Reuse existing Core shapes:

```text
zero-effect Event        -> note identity
EventDescription         -> interpretive text
```

Add only interpretation-specific metadata:

```lean
structure InterpretationEvidence (Time : Type) where
  note : EventId
  subject : EventId
  recordedAt : Time
  attributedAt : Option Time
```

This structure is a design target, not code committed by this checkpoint.

## 3. Keep interpretation notes outside Actual authority

Interpretation note Events must live in a dedicated interpretation memory/image.

Do **not** insert zero-effect interpretation notes into household
`ActualAuthority` merely to reuse `Event`.

Reasons:

- Actual Event identity denotes retained household occurrence evidence;
- interpretation notes have no quantity Effects;
- interpretation recording time is not `ActualValidity.validOn`;
- accounting reports must not begin seeing note Events as household Actuals.

The subject EventId, by contrast, refers into admitted household Actual evidence.

## 4. Candidate in-memory image

The first production slice should compose existing memories with small metadata:

```text
InterpretationImage
  noteEvents    : EventMemory
  descriptions : EventDescriptionMemory
  evidence     : InterpretationEvidenceMemory
```

Admission must require:

1. every interpretation note Event has zero Effects;
2. every metadata `note` resolves in `noteEvents`;
3. every retained note has exactly one EventDescription;
4. every retained note has exactly one InterpretationEvidence row;
5. every metadata `subject` resolves in the admitted household EventMemory;
6. metadata note identities are unique;
7. `recordedAt` is required;
8. `attributedAt` is optional;
9. when `attributedAt` exists, it is not later than `recordedAt`;
10. no text parsing creates hidden subject/time authority.

Cross-memory closure belongs at the admission boundary rather than being inferred
from row order or file names.

## 5. Time representation

Core should stay polymorphic in `Time`, following existing LOAM patterns.

The first household persistence slice may use validated ISO `YYYY-MM-DD`
strings because the qualified queries require ordering by day, not sub-day
chronology.

This does **not** make interpretation time an Actual-validity coordinate.

Recommended household names at presentation/persistence boundaries:

```text
recorded-on
attributed-on
```

The semantic distinction remains the same as the experimental
`recordedAt / attributedAt`.

Do not add timestamp precision until a separate practical question requires it.

## 6. Subject correction law

The stored `subject` is historical provenance.

Example:

```text
stored subject: E0
corrections:    E0 -> E1 -> E2
```

Queries must distinguish:

```text
historical subject = E0
current subject    = E2
```

Current projection should reuse existing correction-frontier machinery:

```text
buildCorrectionFrontierIndex
require index.admissible
require stored subject is present
terminalFrom(correction-count + 1, stored subject)
```

If correction admission fails, current-subject projection fails closed.

The interpretation row itself is never rewritten because a later EventCorrection
appears.

## 7. First persistence shape

Use one dedicated complete image under the household data root.

Candidate filename:

```text
interpretations.loam
```

Candidate version-1 physical row:

```text
LOAM-INTERPRETATIONS<TAB>1
NOTE<TAB><note-id><TAB><subject-event-id><TAB><recorded-on><TAB><attributed-on-or-><TAB><escaped-text>
```

A single physical row is allowed to decode into semantically separate
zero-effect Event, EventDescription, and InterpretationEvidence values.

Physical compactness must not collapse their semantic boundaries.

Reader requirements:

- malformed header/field count/token/date/escape -> reject;
- duplicate note id -> reject;
- unknown subject Event -> reject at household admission;
- empty text -> follow the same explicit text-admissibility policy selected by
  the implementation, never infer meaning from emptiness;
- attributed `-` -> explicit absence, not a default;
- missing file -> no configured interpretation evidence, not evidence that the
  person had no interpretation.

Writer requirements:

- sibling-stage / atomic replacement pattern consistent with current LOAM
  persistence;
- first successful write may bootstrap the file;
- append one complete admitted image under writer ownership;
- never partially publish text without metadata or metadata without text.

## 8. First writer boundary

Candidate surface-independent draft:

```lean
structure AddDraft where
  subject : EventId
  text : String
  recordedAt : String
  attributedAt : Option String
```

The publisher should:

1. read one admitted household Actual snapshot;
2. validate that `subject` is retained;
3. validate dates without borrowing ActualValidity semantics;
4. allocate a fresh local interpretation note EventId;
5. construct a zero-effect note Event;
6. construct its EventDescription;
7. construct InterpretationEvidence;
8. admit the complete next interpretation image;
9. publish atomically.

The first writer must not require `attributedAt`.

Interactive surfaces may later prefill `recordedAt` with today, but the
surface-independent draft should remain deterministic and explicit for tests.

## 9. First read boundary

The first useful read API needs only four query families:

```text
all retained interpretation notes
notes for exact historical subject
notes recorded by cutoff
notes explicitly attributed by cutoff
```

A fifth derived query may expose:

```text
current subject for one retained interpretation
```

using the admitted Correction frontier.

No query should choose one "current interpretation" merely from list order,
recording time, or file position.

## 10. First implementation sequence

Keep production changes small and independently qualified.

### Slice A — Core + admission

Add only:

- InterpretationEvidence;
- bounded memory/uniqueness law;
- interpretation-image admission over note EventMemory, EventDescriptionMemory,
  metadata, and admitted household subject Events.

No persistence or UI yet.

### Slice B — persistence

Add:

- version-1 complete image codec;
- round-trip tests;
- malformed/orphan/duplicate/date/unknown-attribution fixtures;
- sibling-stage publication.

### Slice C — read/query adapter

Add:

- exact historical-subject queries;
- recorded cutoff query;
- explicit-attribution cutoff query;
- current-subject projection through existing CorrectionFrontier.

### Slice D — writer

Add:

- fresh note identity allocation;
- surface-independent AddDraft;
- append publisher;
- bootstrap-on-first-write behavior.

Only after dogfooding those boundaries should CLI/TUI entry be selected.

## 11. Required qualification cases

Before the feature is called usable, tests should pin:

1. one ordinary interpretation round-trip;
2. multiple interpretations on the same subject coexist;
3. contradictory text does not overwrite older text;
4. unknown attributedAt survives round-trip as unknown;
5. unknown is not defaulted to subject date;
6. unknown is not defaulted to recorded date;
7. orphan metadata note is rejected;
8. missing EventDescription is rejected;
9. orphan household subject is rejected;
10. duplicate note metadata is rejected;
11. note Event with quantity Effects is rejected;
12. adding an interpretation does not mutate Actual evidence;
13. later EventCorrection does not mutate stored subject;
14. current-subject projection follows an admitted correction chain;
15. invalid correction topology makes current-subject projection unavailable;
16. persistence/list order carries no currentness or priority meaning.

## 12. Explicitly deferred

Do not include these in the first implementation:

- subjects that are Scheduled, Attention, another interpretation, or arbitrary
  external objects;
- automatic capture from ChatGPT/AI conversation;
- causal inference;
- mood/relationship ontology;
- confidence scores;
- sentiment values;
- real-number or complex-number semantics;
- automatic attributed-time inference;
- note editing/deletion/correction UI;
- a singleton current-interpretation authority;
- TUI diary prompts;
- accounting/export integration;
- Beancount/Fava export of reflection text.

## 13. Privacy / export boundary

Interpretive free text may contain substantially more personal context than an
ordinary accounting description.

Therefore the first implementation must:

- keep interpretation text inside the selected household data root;
- not include it in existing accounting exports by default;
- not auto-publish it to external services;
- not infer consent to move it into another repository or data surface.

## 14. Stop point

The semantic field discovery is closed for the first slice.

The next step after merging the research chain is **production implementation
Slice A**, not another ontology experiment.

If Slice A encounters a concrete contradiction that cannot satisfy the qualified
Observations 320–327, reopen the relevant observation rather than silently
widening the model.
