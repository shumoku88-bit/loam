# Attention delivery obligation DAG — G2-009

Status: **Generation-2 audit evidence**

Primary instruments: **DRAKONview + obligation DAG**.

G2-009 was triggered by a practical observation: Attention feels non-functional in real use, including the TUI. The audit therefore does not start from an assumption that the small `AttentionReview` boundary is a finished feature. It separates semantic readiness from delivery maturity.

## 1. Current read spine

The selected production read path is:

```text
attention.loam
    |
    v
AttentionPersistence
    |
    v
Application.openAttentions?
    |
    v
AttentionReview.Availability
    |
    v
Tui.Attention
```

The obligations are intentionally separated:

```text
configured source?
    |
    +-- no  -> Availability.unavailable
    |
    +-- yes -> decode typed complete image
                    |
                    +-- malformed -> refuse
                    |
                    +-- admitted -> closureReferencesKnown
                                          |
                                          +-- false -> refuse
                                          |
                                          +-- true -> project open items
```

The TUI then preserves one further distinction:

```text
Unavailable != configured empty stream == 0 open
```

This is a justified distinction. Missing household evidence must not become a claim that the household has zero open matters.

Verdict for the read spine: **KEEP**.

No read-specific lifecycle engine, second open-item model, optional-date collapse, due sorting, or priority semantics is justified.

## 2. Why the feature still feels absent

The read path is not the whole product capability.

At G2-009 main:

- `loam-data` has no `attention.loam`;
- `AttentionPersistence.saveAttentionMemory?` can serialize a complete image;
- there is no production `AttentionPublisher`;
- there is no dedicated Attention authority/update boundary;
- `HouseholdCommand` has no Attention command entrance;
- `Tui.Attention` is explicitly read-only;
- there are no TUI verbs for add, resolve, or drop.

The practical topology is therefore:

```text
                    READ
Core -> Persistence -> Application -> Review -> TUI
  ^                                        |
  |                                        v
  +---------------- semantically coherent

                    WRITE
TUI verb -> HouseholdCommand -> Publisher -> Authority
   X              X              X           X

household data:
attention.loam X
```

The delivery gap explains the apparent non-functionality better than a defect in `AttentionReview`.

Verdict: **READ KEEP / DELIVERY INCOMPLETE**.

## 3. Existing retained distinctions already constrain the first writer

The Core already retains enough meaning for a small practical write slice:

```text
Attention
  id
  context
  due = dueOn | noDueDate | dueUndetermined

AttentionClosure
  attention
  knownOn
  kind = resolved | dropped
```

`AttentionMemory` permits append with unique identity. `AttentionClosureMemory` permits at most one closure per Attention identity. Current inspection refuses dangling closures.

Therefore the first production writer does not need to invent a richer issue ontology.

## 4. Smallest earned write DAG

A first useful writer can be decomposed into three explicit commands.

### Add

```text
load current image
    |
    v
fresh AttentionId
    |
    v
explicit context + explicit due meaning
    |
    v
AttentionMemory.add?
    |
    v
save complete image
```

### Resolve

```text
load current image
    |
    v
known AttentionId?
    |
    v
currently open?
    |
    v
explicit knownOn
    |
    v
AttentionClosureMemory.add? RESOLVED
    |
    v
save complete image
```

### Drop

The same path is used with explicit `DROPPED` closure meaning.

These are independent command leaves over one existing authority image. They do not require mutable status fields or deletion of historical evidence.

## 5. What G2-009 does not earn

The following remain outside the first write slice unless separate pressure earns them:

- editing Attention context or due evidence;
- correcting mistaken closure evidence;
- reopening a closed Attention;
- due-date sorting as household meaning;
- priority;
- category/taxonomy;
- amount/account fields;
- selected-day membership inference;
- automatic Event linkage;
- Attention-to-Event or Attention-to-Attention provenance relations;
- recurrence/continuation rules;
- report integration beyond consuming the existing read answer.

In particular, relation provenance was explored historically but current Core documentation explicitly says it has no selected persistence, authority, publisher, or current consumer. It should not be smuggled into the first writer merely because a UI action could use it later.

## 6. Authority shape

`AttentionPersistence.saveAttentionMemory?` is a physical complete-image write primitive, not yet a production mutation authority. A production writer must still own:

- exclusive writer ownership for `attention.loam`;
- authoritative re-read inside that ownership interval;
- command admission against the fresh image;
- publication of one complete image;
- error/refusal behavior;
- stable file selection so TUI and publisher agree on one canonical Attention source.

The smallest likely topology is:

```text
TUI
 |
 v
HouseholdCommand
 |
 v
AttentionPublisher
 |
 v
Attention authority ownership
 |
 +-> load fresh complete image
 +-> admit Add / Resolve / Drop
 +-> save complete image
 |
 v
AttentionReview on next read
```

This is a delivery boundary, not a new semantic engine.

## 7. G2-009 verdict

```text
Attention Core                 KEEP
Attention Persistence codec    KEEP
Application lifecycle/open     KEEP
AttentionReview                KEEP
read-only TUI projection       KEEP
household Attention evidence   MISSING
production authority/publisher MISSING
HouseholdCommand entrance      MISSING
TUI write verbs                MISSING
```

Overall verdict: **READ SPINE KEEP; DELIVERY MATURATION CANDIDATE**.

The next useful step is not another compression pass over `AttentionReview`. It is a separate production feature slice that adds the smallest admitted Attention write spine while reusing the existing Core, persistence, Application, and Review semantics.
