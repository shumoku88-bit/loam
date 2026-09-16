# G2-032 — Attention delivery closure obligation DAG

Status: **Generation-2 audit evidence — KEEP / DELIVERY GAP CLOSED**

Primary instruments: **DRAKONview + obligation DAG + source/history cross-check**.

## Question

G2-009 found a coherent Attention read spine but no production write spine. It explicitly left a maturation candidate:

```text
TUI -> HouseholdCommand -> AttentionPublisher -> writer ownership -> attention.loam
```

PR #927 later implemented that candidate. G2-032 asks a narrower current-main question:

> Is the G2-009 delivery gap still structurally open, or did the later writer close it without introducing a second lifecycle model or a new unjustified presentation owner?

The audit baseline is main at `d75c4e19199297c2c3e983201a6f389d293b0135` after PR #974.

## 1. Current end-to-end topology

The retained lifecycle meaning is still owned by the original Attention family:

```text
Core.Attention
  item identity
  opaque context
  dueOn | noDueDate | dueUndetermined
  resolved | dropped closure evidence
```

Persistence retains one complete image of items plus closures. Application owns current-open projection and rejects dangling closure evidence. `AttentionReview` preserves:

```text
unavailable != configured empty == 0 open
```

The production write path now exists:

```text
AttentionAdministration
        |
        v
AttentionAdministrationSession
        |
        v
HouseholdCommand
        |
        v
AttentionPublisher
        |
        v
WriterOwnership(attention.loam)
        |
        +--> re-read complete image
        +--> admit Add or Close
        +--> save complete image
        |
        v
AttentionReview reload
```

This is the exact maturation direction earned by G2-009 rather than a second semantic engine.

## 2. Add obligations

`AttentionPublisher.add` owns only publication obligations that must remain surface-independent:

```text
canonical path selected by HouseholdCommand
path non-empty
concrete due date, when present, is a real calendar date
writer ownership
fresh re-read, or empty bootstrap when the file is absent
fresh AttentionId
AttentionMemory.add?
complete-image save
```

The publisher deliberately does not add priority, taxonomy, amount, selected-day membership, provenance, or mutable status.

`context` remains the opaque Core string selected by the existing model. The administration TUI rejects an empty interactive entry as presentation guidance; that is not promoted into a new Core invariant.

## 3. Close obligations

`AttentionPublisher.close` re-admits the durable intent under ownership:

```text
closure knownOn is a real calendar date
fresh complete-image re-read
closure target is retained
no closure already exists for that AttentionId
AttentionClosureMemory.add?
complete-image save
```

The read side later applies `openAttentions?`, which independently refuses dangling closure evidence before projecting current-open items.

These are complementary boundaries, not duplicated lifecycle engines:

- writer admission prevents production from appending a dangling or duplicate closure;
- reader admission remains necessary because configured evidence may predate the writer, be externally edited, or otherwise be malformed.

Removing either boundary would weaken fail-closed behavior.

## 4. Canonical reload obligation

The administration session does not trust its local editor state after publication.

After successful Add or Close it reloads:

```text
root / "attention.loam"
        |
        v
AttentionReview.loadEvidence
        |
        v
AttentionAdministration.refreshed
```

The next visible state is therefore projected from canonical retained evidence. The TUI does not become a second state authority.

## 5. Why two TUI surfaces remain

Current main intentionally has two different product entrances:

### Integrated `loamTui`

`Loam.Tui.Attention` is a recognition-oriented read-only workspace. It preserves unavailable versus configured-empty and exposes no lifecycle command.

### Standalone `loamAttention`

`Loam.Tui.AttentionAdministration` is a small management surface with selection plus Add / Resolve / Drop. `AttentionAdministrationSession` owns the terminal/effect shell and delegates durable intent through `HouseholdCommand`.

This physical split was introduced for an independent reason in PR #927: mature the writer without enlarging the integrated `loamTui` state machine. The two surfaces also have different navigation contracts. The standalone program can treat its back/quit keys as termination of the whole program, while the integrated workspace must preserve LOAM root navigation semantics.

There is some presentation resemblance in their open-item lists, but G2-032 finds no duplicated lifecycle rule or canonical state owner. Extracting a shared browse widget or replacing the integrated workspace with the administration session would add adapter/navigation surface without removing a semantic duplication.

Verdict: **KEEP both surfaces for now**.

Revisit only if product work explicitly makes Attention writes part of integrated `loamTui`; at that point the ownership question changes.

## 6. G2-009 gap status

The historical G2-009 statement remains true for its original baseline, but the current production state is now:

```text
Attention Core                  KEEP
Attention Persistence codec     KEEP
Application lifecycle/open      KEEP
AttentionReview                 KEEP
integrated read-only TUI        KEEP
AttentionPublisher              PRESENT
HouseholdCommand entrance       PRESENT
standalone Add/Resolve/Drop TUI PRESENT
canonical post-write reload     PRESENT
```

The missing authority/write path identified by G2-009 is therefore **closed**.

The remaining absence of write verbs in integrated `loamTui` is a product entrance choice, not evidence that Attention lacks a production writer.

## 7. Obligation DAG

```text
                         retained Attention meaning
                                  |
                 +----------------+----------------+
                 |                                 |
                 v                                 v
               READ                              WRITE
                 |                                 |
      Persistence complete image          HouseholdCommand path
                 |                                 |
      Application open projection          WriterOwnership
                 |                                 |
      dangling closure refusal             fresh image re-read
                 |                                 |
      AttentionReview                 +-----------+-----------+
                 |                    |                       |
       unavailable / empty            v                       v
                 |                   ADD                    CLOSE
                 |                    |                       |
                 |              fresh identity        known retained target
                 |                    |                not already closed
                 |                    +-----------+-----------+
                 |                                |
                 |                         save complete image
                 |                                |
                 +-----------------------< reload >
                                  |
                                  v
                         canonical visible answer
```

No branch above earns a new semantic abstraction.

## 8. Verdict

```text
G2-009 read spine                         KEEP
G2-009 missing production writer          CLOSED by #927
AttentionPublisher authority boundary     KEEP
writer-side target/duplicate admission    KEEP
reader-side dangling-reference admission  KEEP
post-write canonical reload               KEEP
integrated read-only Attention workspace  KEEP
standalone administration surface         KEEP
new shared Attention presentation layer   DO NOT ADD
production refactor                       NONE
```

**G2-032: KEEP / DELIVERY GAP CLOSED.**

This is a stop result. The audit found no current structural pressure worth a production change.